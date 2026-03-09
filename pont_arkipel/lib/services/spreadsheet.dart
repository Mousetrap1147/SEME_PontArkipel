import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class SpreadsheetService {
  static Future<bool> pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm'],
    );

    if (result == null) return false;

    final file = File(result.files.single.path!);
    final bytes = file.readAsBytesSync();

    final decoder = SpreadsheetDecoder.decodeBytes(bytes);

    for (var table in decoder.tables.keys) {
      print("Sheet: $table");
      print("Rows: ${decoder.tables[table]?.rows.length}");
    }

    return true;
  }
}