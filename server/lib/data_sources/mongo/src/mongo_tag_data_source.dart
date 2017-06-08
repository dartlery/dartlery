import 'dart:async';
import 'package:dartlery_shared/tools.dart';
import 'package:option/option.dart';
import 'package:dartlery/data/data.dart';
import 'package:dartlery/data_sources/interfaces/interfaces.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:dartlery_shared/global.dart';
import 'a_mongo_two_id_data_source.dart';
import 'constants.dart';

class MongoTagDataSource extends AMongoTwoIdDataSource<TagInfo>
    with ATagDataSource {
  static final Logger _log = new Logger('MongoTagDataSource');

  @override
  Logger get childLogger => _log;

  static const String categoryField = 'category';
  static const String fullNameField = "fullName";
  static const String redirectField = "redirect";
  static const String countField = "count";

  MongoTagDataSource(MongoDbConnectionPool pool) : super(pool);

  @override
  String get secondIdField => categoryField;

  @override
  TagInfo createObject(Map data) {
    return staticCreateObject(data);
  }

  static Tag staticCreateObject(Map data) {
    final TagInfo output = new TagInfo();
    if (data[redirectField] != null) {
      output.redirect = staticCreateObject(data[redirectField]);
    }

    AMongoTwoIdDataSource.setIdForData(output, data);
    output.category = data[categoryField];
    output.count = data[countField] ?? 0;
    return output;
  }

  @override
  Future<List<TagInfo>> getRedirects() async {
    return new List<TagInfo>.from(
        await getFromDb(where.exists("$redirectField.$idField")));
  }

  SelectorBuilder _createTagCriteria(String id, String category, {String fieldPrefix = ""}) {
    if(StringTools.isNotNullOrWhitespace(fieldPrefix))
      fieldPrefix = "$fieldPrefix.";

    final SelectorBuilder select = where
        .eq("$fieldPrefix$idField", {$regex: "^$id\$", $options: '-i'});

    if(StringTools.isNullOrWhitespace(category)) {
      select.eq(
          "$fieldPrefix$categoryField",null);
    } else {
      select.eq(
          "$fieldPrefix$categoryField",
          {$regex: "^$category\$", $options: '-i'});
    }


    return select;
  }

  @override
  Future<List<TagInfo>> getByRedirect(String id, String category) async {
    final SelectorBuilder select = _createTagCriteria(id, category, fieldPrefix: redirectField);
    return new List<TagInfo>.from(await getFromDb(select));
  }

  @override
  Future<Option<TagInfo>> getById(String id, String category) async {
    final SelectorBuilder select = _createTagCriteria(id, category);
    return getForOneFromDb(select);
  }

  @override
  Future<Null> deleteByRedirect(String id, String category) async {
    await deleteFromDb(where
        .eq("$redirectField.$idField", id)
        .eq("$redirectField.$categoryField", category));
  }

  @override
  Future<String> update(String id, String category, Tag object) async {
    final SelectorBuilder select = _createTagCriteria(id, category, fieldPrefix: redirectField);
    final String output = await super.update(id, category, object);
    await genericUpdate(select,
        modify
            .set("$redirectField.$idField", object.id)
            .set("$redirectField.$categoryField", object.category));
    return output;
  }

  @override
  Future<int> countTagUse(Tag t) async {
    return databaseWrapper<int>((MongoDatabase con) async {
      final DbCollection itemsCol = await con.getItemsCollection();
      return await itemsCol.count(where.eq("tags", {
        $elemMatch: {idField: t.id, categoryField: t.category}
      }));
    });
  }

  @override
  Future<IdDataList<TagInfo>> search(String query,
      {SelectorBuilder selector,
      String sortBy,
      int limit,
      bool countAsc: true}) async {
    SelectorBuilder sb;
    if (selector == null)
      sb = where;
    else
      sb = selector;

    sb = sb
        .match(fullNameField, ".*$query.*",
            multiLine: false, caseInsensitive: true, dotAll: true)
        .sortBy(countField, descending: !countAsc)
        .sortBy(sortBy ?? fullNameField)
        .limit(limit ?? 25);

    return await super.getListFromDb(sb);
  }

  @override
  Future<Null> refreshTagCount(List<Tag> tags) async {
    if (tags.length == 0) throw new ArgumentError.notNull("tags");

    for (Tag t in tags) {
      final int count = await countTagUse(t);
      final SelectorBuilder select =
          where.eq(idField, t.id).eq(categoryField, t.category);
      await genericUpdate(select, modify.set(countField, count),
          multiUpdate: false);
    }
  }

  @override
  Future<Null> incrementTagCount(List<Tag> tags, int amount) async {
    if (tags.length == 0) throw new ArgumentError.notNull("tags");
    if (amount == 0) throw new ArgumentError.value(amount, "amount");

    final SelectorBuilder select =
        where.eq(idField, tags[0].id).eq(categoryField, tags[0].category);
    for (int i = 1; i < tags.length; i++) {
      select.or(
          where.eq(idField, tags[i].id).eq(categoryField, tags[i].category));
    }

    final ModifierBuilder modifier = modify.inc(countField, amount);

    await genericUpdate(select, modifier, multiUpdate: true);
  }

  @override
  Future<Null> cleanUpTags() async {
    await databaseWrapper((MongoDatabase con) async {
      final DbCollection itemsCol = await con.getItemsCollection();
      final DbCollection tagCol = await con.getTagsCollection();

      final Stream<Map> pipe = itemsCol.aggregateToStream([
        {$unwind: "\$tags"},
        {
          $group: {
            "_id": "\$tags",
            "count": {$sum: 1}
          }
        }
      ]);
      await for (Map agr in pipe) {
        final Tag t =
            new Tag.withValues(agr["_id"][idField], agr["_id"][categoryField]);

        if (!await existsById(t.id, t.category))
          await create(new TagInfo.copy(t));

        await tagCol.update(
            where.eq(idField, t.id).eq(categoryField, t.category),
            modify.set(countField, agr["count"]),
            multiUpdate: false);
      }

      final SelectorBuilder select =
          where.eq(countField, 0).notExists(redirectField);
      await tagCol.remove(select);
    });
  }

  @override
  Future<DbCollection> getCollection(MongoDatabase con) =>
      con.getTagsCollection();

  @override
  void updateMap(TagInfo tag, Map data) {
    staticUpdateMap(tag, data);
  }

  static void staticUpdateMap(Tag tag, Map data, {bool onlyKeys: false}) {
    AMongoTwoIdDataSource.staticUpdateMap(tag, data);
    if (StringTools.isNullOrWhitespace(tag.category))
      data[categoryField] = null;
    else
      data[categoryField] = tag.category;
    if (!onlyKeys) {
      data[fullNameField] = tag.fullName;

      if (tag is TagInfo && tag.redirect != null) {
        final Map redirect = {};
        staticUpdateMap(tag.redirect, redirect, onlyKeys: true);
        data[redirectField] = redirect;
      } else if (data.containsKey(redirectField)) {
        data.remove(redirectField);
      }
    }
    // Note: We do not update the tag count, that is only done by increment functions
  }

  static List<Map> createTagsList(List<Tag> tags, {bool onlyKeys: false}) {
    final List<Map> output = <Map>[];
    for (Tag tag in tags) {
      final Map<dynamic, dynamic> tagMap = <dynamic, dynamic>{};
      MongoTagDataSource.staticUpdateMap(tag, tagMap, onlyKeys: onlyKeys);
      output.add(tagMap);
    }
    return output;
  }
}
