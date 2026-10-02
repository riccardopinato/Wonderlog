import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/capture/domain/capture_models.dart';
import '../../features/smart_journey/domain/smart_journey_models.dart';

final class DeviceContentPicker {
  const DeviceContentPicker();

  Future<List<CaptureIncomingItem>> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return const [];
    return result.files.take(100).map((file) => CaptureIncomingItem(
      id: const Uuid().v4(),
      type: CaptureContentType.image,
      uri: _referenceFor(file),
      title: file.name,
      mimeType: _mimeFor(file.extension),
    )).where((item) => (item.uri ?? '').isNotEmpty).toList(growable: false);
  }

  Future<List<CaptureIncomingItem>> pickKeepsakes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return const [];
    return result.files.take(30).map((file) => CaptureIncomingItem(
      id: const Uuid().v4(),
      type: CaptureContentType.file,
      uri: _referenceFor(file),
      title: file.name,
      mimeType: _mimeFor(file.extension),
    )).where((item) => (item.uri ?? '').isNotEmpty).toList(growable: false);
  }

  Future<List<SmartJourneySourcePhoto>> pickSmartJourneyPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return const [];
    final now = DateTime.now();
    return result.files.take(100).toList(growable: false).asMap().entries.map(
      (entry) => SmartJourneySourcePhoto(
        sourceUri: _referenceFor(entry.value),
        originalIndex: entry.key,
        modifiedAt: now.add(Duration(milliseconds: entry.key)),
      ),
    ).where((item) => item.sourceUri.isNotEmpty).toList(growable: false);
  }

  String _referenceFor(PlatformFile file) {
    final path = file.path?.trim();
    if (path != null && path.isNotEmpty) return path;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return '';
    final mime = _mimeFor(file.extension);
    return 'data:' + mime + ';base64,' + base64Encode(bytes);
  }

  String _mimeFor(String? extension) => switch (extension?.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}
