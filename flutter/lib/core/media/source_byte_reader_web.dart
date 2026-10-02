import 'dart:convert';
import 'dart:typed_data';

abstract interface class SourceByteReader {
  Future<Uint8List> read(String reference);
}

final class PlatformSourceByteReader implements SourceByteReader {
  const PlatformSourceByteReader();

  @override
  Future<Uint8List> read(String reference) async {
    final normalized = reference.trim();
    if (!normalized.startsWith('data:')) {
      throw UnsupportedError(
        'Web media imports require a data URI supplied by the picker adapter.',
      );
    }
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
}
