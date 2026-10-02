import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import 'ecosystem_inbound_transfer_service.dart';

final class EcosystemDeepLinkListener extends StatefulWidget {
  const EcosystemDeepLinkListener({
    super.key,
    required this.inboundService,
    required this.child,
  });

  final EcosystemInboundTransferService inboundService;
  final Widget child;

  @override
  State<EcosystemDeepLinkListener> createState() =>
      _EcosystemDeepLinkListenerState();
}

final class _EcosystemDeepLinkListenerState
    extends State<EcosystemDeepLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _appLinks.uriLinkStream.listen(_handleUri);
    _readInitialLink();
  }

  Future<void> _readInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) await _handleUri(uri);
    } catch (_) {
      // Malformed or unsupported platform links fail closed.
    }
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme != 'wonderlog' ||
        uri.host != 'ecosystem' ||
        uri.path != '/import') {
      return;
    }
    await widget.inboundService.acceptUri(uri);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
