import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final class KeepsakeFileActions {
  const KeepsakeFileActions();

  Future<void> open({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final uri = Uri.parse(
      'data:$mimeType;base64,${base64Encode(bytes)}',
    );
    final opened = await launchUrl(uri);
    if (!opened) {
      throw StateError('Unable to open keepsake in browser.');
    }
  }

  Future<void> share({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) =>
      SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: _safeName(fileName),
              mimeType: mimeType,
            ),
          ],
        ),
      );

  Future<String?> export({
    required List<int> bytes,
    required String fileName,
  }) =>
      FilePicker.platform.saveFile(
        dialogTitle: 'Export keepsake',
        fileName: _safeName(fileName),
        bytes: Uint8List.fromList(bytes),
      );

  String _safeName(String raw) {
    final normalized = raw.trim().isEmpty ? 'keepsake.bin' : raw.trim();
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
  }
}
