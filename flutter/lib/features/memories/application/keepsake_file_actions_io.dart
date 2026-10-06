import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final class KeepsakeFileActions {
  const KeepsakeFileActions();

  Future<void> open({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final path = await _materialize(bytes, fileName);
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }

  Future<void> share({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final path = await _materialize(bytes, fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            path,
            name: _safeName(fileName),
            mimeType: mimeType,
          ),
        ],
      ),
    );
  }

  Future<String?> export({
    required List<int> bytes,
    required String fileName,
  }) =>
      FilePicker.platform.saveFile(
        dialogTitle: 'Export keepsake',
        fileName: _safeName(fileName),
        bytes: Uint8List.fromList(bytes),
      );

  Future<String> _materialize(List<int> bytes, String fileName) async {
    final root = await getTemporaryDirectory();
    final dir = Directory(p.join(root.path, 'wonderlog_keepsakes'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, _safeName(fileName)));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _safeName(String raw) {
    final normalized = raw.trim().isEmpty ? 'keepsake.bin' : raw.trim();
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
  }
}
