import 'package:dartlery/api/api.dart';
import 'package:dartlery_shared/tools.dart';
import 'package:dartlery_shared/global.dart';

class TagWrapper {
  final Tag tag;

  TagWrapper(this.tag);

  String get id => tag.toString();

  @override
  String toString() =>formatTag(this.tag);

  static String formatTag(Tag tag) {
    if(StringTools.isNotNullOrWhitespace(tag.category)) {
      return "${tag.category}$categoryDeliminator ${tag.id}";
    } else {
      return tag.id;
    }
  }
  static String formatRedirectingTag(RedirectingTag tag) {
    if(StringTools.isNotNullOrWhitespace(tag.category)) {
      return "${tag.category}$categoryDeliminator ${tag.id}";
    } else {
      return tag.id;
    }
  }

  static String createQueryString(Tag tag) {
    if(tag==null)
      throw new ArgumentError.notNull("tag");

    final String tagString = Uri.encodeFull(tag.id).replaceAll(":", "%3A").replaceAll(",","%2C");
    final String categoryString = Uri.encodeFull(tag.category??"").replaceAll(":", "%3A").replaceAll(",","%2C");
    if(StringTools.isNotNullOrWhitespace(categoryString)) {
      return "$categoryString$categoryDeliminator$tagString";
    } else {
      return tagString;
    }
  }

  String toQueryString() => createQueryString(tag);

  bool equals(TagWrapper other) {
    if(tag.id?.toLowerCase()==other.tag.id?.toLowerCase()
        &&tag.category?.toLowerCase()==other.tag.category?.toLowerCase()) {
      return true;
    }
    return false;
  }
}