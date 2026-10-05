import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/ecosystem/ecosystem_registry.dart';
import '../../../core/ecosystem/ecosystem_transfer_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../ecosystem/presentation/ecosystem_inbox_page.dart';

final class EcosystemInboxHomeCard extends StatelessWidget {
  const EcosystemInboxHomeCard({
    super.key,
    required this.store,
  });

  final EcosystemTransferStore store;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return StreamBuilder<List<EcosystemInboxItem>>(
      stream: store.watchPendingInbox(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? const <EcosystemInboxItem>[];
        if (pending.isEmpty) return const SizedBox.shrink();

        final item = pending.last;
        final envelope = item.envelope;
        final sourceName =
            EcosystemRegistry.definition(item.sourceApp).displayName;
        final rawTitle = envelope.title?.trim() ?? '';
        final fallback = envelope.fallback.plainText.trim();
        final title = rawTitle.isNotEmpty
            ? rawTitle
            : fallback.split(RegExp(r'[\r\n]+')).firstWhere(
                  (line) => line.trim().isNotEmpty,
                  orElse: () => envelope.sourceEntityType.name,
                );
        final body = envelope.text?.trim() ?? '';

        return Card(
          margin: const EdgeInsets.only(
            top: WonderlogSpacing.medium,
            bottom: WonderlogSpacing.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.hub_outlined),
                    ),
                    const SizedBox(width: WonderlogSpacing.small),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.ecosystemInboxTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: WonderlogSpacing.xSmall),
                          Text(
                            '${strings.ecosystemInboxReceivedFrom} $sourceName',
                          ),
                        ],
                      ),
                    ),
                    if (pending.length > 1)
                      Badge(
                        label: Text('${pending.length}'),
                      ),
                  ],
                ),
                const SizedBox(height: WonderlogSpacing.medium),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (body.isNotEmpty && body != title) ...[
                  const SizedBox(height: WonderlogSpacing.xSmall),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: WonderlogSpacing.small),
                Wrap(
                  spacing: WonderlogSpacing.xSmall,
                  runSpacing: WonderlogSpacing.xSmall,
                  children: [
                    Chip(
                      label: Text(envelope.transferMode.name.toUpperCase()),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(envelope.sourceEntityType.name),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: WonderlogSpacing.small),
                Text(
                  strings.ecosystemInboxStoredDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: WonderlogSpacing.small),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EcosystemInboxPage(),
                      ),
                    ),
                    icon: const Icon(Icons.inbox_outlined),
                    label: Text(strings.ecosystemInboxOpen),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
