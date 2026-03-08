import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ExcelService {
  static Future<bool> pickExcel() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xlsm'],
  );

  if (result == null) return false;

  print(result.files.single.path);

  return true;
}
}