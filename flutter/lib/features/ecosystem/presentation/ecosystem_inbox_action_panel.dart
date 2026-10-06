import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';

final class EcosystemInboxActionPanel extends StatefulWidget {
  const EcosystemInboxActionPanel({
    super.key,
    required this.onAddToJourney,
    required this.onCreateJourney,
    required this.onSaveFreeMemory,
    required this.onIgnore,
  });

  final Future<void> Function() onAddToJourney;
  final Future<void> Function() onCreateJourney;
  final Future<void> Function() onSaveFreeMemory;
  final Future<void> Function() onIgnore;

  @override
  State<EcosystemInboxActionPanel> createState() =>
      _EcosystemInboxActionPanelState();
}

final class _EcosystemInboxActionPanelState
    extends State<EcosystemInboxActionPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final enabled = !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: WonderlogSpacing.small),
        ],
        Wrap(
          spacing: WonderlogSpacing.small,
          runSpacing: WonderlogSpacing.small,
          children: [
            FilledButton.tonalIcon(
              onPressed: enabled ? () => _run(widget.onAddToJourney) : null,
              icon: const Icon(Icons.luggage_outlined),
              label: Text(strings.ecosystemAddExistingJourney),
            ),
            FilledButton.tonalIcon(
              onPressed: enabled ? () => _run(widget.onCreateJourney) : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(strings.ecosystemCreateJourney),
            ),
            FilledButton.tonalIcon(
              onPressed: enabled ? () => _run(widget.onSaveFreeMemory) : null,
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(strings.ecosystemSaveFreeMemory),
            ),
            OutlinedButton.icon(
              onPressed: enabled ? () => _run(widget.onIgnore) : null,
              icon: const Icon(Icons.archive_outlined),
              label: Text(strings.ecosystemIgnoreArchive),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
