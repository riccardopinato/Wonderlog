import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveExportedFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Wonderlog export',
    fileName: fileName,
  );
  if (path == null) return null;
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
