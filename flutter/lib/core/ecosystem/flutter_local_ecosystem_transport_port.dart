import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ecosystem_local_transport_port.dart';

final class FlutterLocalEcosystemTransportPort
    implements EcosystemLocalTransportPort {
  const FlutterLocalEcosystemTransportPort();

  @override
  Future<bool> tryOpen(Uri targetUri) async {
    try {
      // Do not gate custom-scheme handoffs behind canLaunchUrl().
      // On Android 11+ package visibility can make canLaunchUrl() return false
      // even when the explicit ACTION_VIEW launch would succeed. The ecosystem
      // contract already treats a failed launch as the signal to use the
      // portable clipboard fallback, so attempt the real external launch first.
      return await launchUrl(
        targetUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> copyPortableFallback(String portablePayload) =>
      Clipboard.setData(ClipboardData(text: portablePayload));
}
