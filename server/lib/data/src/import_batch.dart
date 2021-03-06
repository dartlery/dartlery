import 'package:dartlery_shared/tools.dart';
import 'a_id_data.dart';
import 'package:rpc/rpc.dart';

@ApiMessage(includeSuper: true)
class ImportBatch extends AIdData {
  DateTime timestamp;
  String source;
  Map<String, int> importCounts = <String, int>{};
  bool finished = false;

  ImportBatch() : super.withValues(generateUuid());

  void addImportResult(String result) {
    if (!importCounts.containsKey(result)) importCounts[result] = 0;

    importCounts[result]++;
  }
}
