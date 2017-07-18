import 'dart:async';

import 'package:dartlery/data/data.dart';
import 'package:dartlery/data_sources/interfaces/interfaces.dart';
import 'package:dartlery_shared/global.dart';
import 'package:dartlery_shared/tools.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:option/option.dart';

import 'a_mongo_data_source.dart';
import 'a_mongo_two_id_data_source.dart';
import 'constants.dart';

class MongoImportResultsDataSource extends AMongoObjectDataSource<ImportResult>
    with AImportResultsDataSource {
  static final Logger _log = new Logger('MongoImportResultsDataSource');
  static const String fileNameField = "fileName";

  static const String resultField = "result";
  static const String errorField = "error";
  static const String sourceField = "source";
  static const String timestampField = "timestamp";
  static const String batchTimestampField = "batchTimestamp";
  static const String thumbnailCreatedField = "thumbnailCreated";
  MongoImportResultsDataSource(MongoDbConnectionPool pool) : super(pool);

  @override
  Logger get childLogger => _log;

  Future<Null> clear([bool everything = false]) async {
    if (!everything) {
      await deleteFromDb(where.nin(resultField, ["error", "warning"]));
    } else {
      await deleteFromDb({});
    }
  }

  @override
  Future<ImportResult> createObject(Map<String, dynamic> data) async {
    final ImportResult output = new ImportResult();
    output.id = data[idField];
    output.fileName = data[fileNameField];
    output.result = data[resultField];
    output.error = data[errorField];
    output.thumbnailCreated = data[thumbnailCreatedField];
    output.source = data[sourceField];
    output.timestamp = data[timestampField];
    return output;
  }

  Future<PaginatedData<ImportResult>> get({int page: 0, int perPage}) async {
    return await getPaginatedFromDb(
        where.sortBy(timestampField, descending: true));
  }

  @override
  Future<DbCollection> getCollection(MongoDatabase con) =>
      con.getImportResultsCollection();

  @override
  Future<Null> record(ImportResult data) async {
    await insertIntoDb(data);
  }

  @override
  void updateMap(ImportResult item, Map<String, dynamic> data) {
    data[idField] = item.id;
    data[fileNameField] = item.fileName;
    data[resultField] = item.result;
    data[thumbnailCreatedField] = item.thumbnailCreated;
    data[errorField] = item.error;
    data[sourceField] = item.source;
    data[timestampField] = item.timestamp;
    data[batchTimestampField] = item.batchTimestamp;
  }
}