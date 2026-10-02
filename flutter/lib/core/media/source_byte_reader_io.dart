import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

abstract interface class SourceByteReader {
  Future<Uint8List> read(String reference);
}

final class PlatformSourceByteReader implements SourceByteReader {
  const PlatformSourceByteReader();

  @override
  Future<Uint8List> read(String reference) async {
    final normalized = reference.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(reference, 'reference', 'Source is required.');
    }

    if (normalized.startsWith('data:')) {
      final comma = normalized.indexOf(',');
      if (comma <= 0) throw const FormatException('Invalid data URI.');
      final metadata = normalized.substring(0, comma);
      final payload = normalized.substring(comma + 1);
      return Uint8List.fromList(
        metadata.endsWith(';base64')
            ? base64Decode(payload)
            : utf8.encode(Uri.decodeComponent(payload)),
      );
    }

    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'file') {
        return File.fromUri(uri).readAsBytes();
      }
      if (uri.scheme == 'content') {
        throw UnsupportedError(
          'content:// requires the Android share/picker platform adapter.',
        );
      }
    }

    return File(normalized).readAsBytes();
  }
}
