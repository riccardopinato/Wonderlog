import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveExportedFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Save Wonderlog export',
    fileName: fileName,
    bytes: bytes,
  );
  return fileName;
}
