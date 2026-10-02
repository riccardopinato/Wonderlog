import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ecosystem_local_transport_port.dart';

final class FlutterLocalEcosystemTransportPort
    implements EcosystemLocalTransportPort {
  const FlutterLocalEcosystemTransportPort();

  @override
  Future<bool> tryOpen(Uri targetUri) async {
    try {
      if (!await canLaunchUrl(targetUri)) return false;
      return launchUrl(targetUri);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> copyPortableFallback(String portablePayload) =>
      Clipboard.setData(ClipboardData(text: portablePayload));
}
