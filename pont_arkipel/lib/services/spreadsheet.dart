import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

enum FileTypeExcel { clients, famille, rdv }

class SpreadsheetService {
  static final Map<FileTypeExcel, SpreadsheetDecoder> _decoders = {};

  static Future<void> pickFile(FileTypeExcel type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm'],
    );

    if (result == null) return;

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    final decoder = SpreadsheetDecoder.decodeBytes(bytes);

    _decoders[type] = decoder;

    print("${type.name} file loaded");
  }

  static Stream<Map<String, dynamic>> read(FileTypeExcel type) async* {
    final decoder = _decoders[type];

    if (decoder == null) {
      throw Exception("${type.name} file not loaded");
    }

    final rows = decoder.tables['A']!.rows;

    if (rows.isEmpty) return;

    final headers = rows.first.map((e) => e.toString()).toList();

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final Map<String, dynamic> rowMap = {};
      for (int j = 0; j < headers.length; j++) {
        rowMap[headers[j]] = j < row.length ? row[j] : null;
      }
      yield rowMap;
    }
  }
}