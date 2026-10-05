import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/ecosystem_registry.dart';
import '../../../core/ecosystem/ecosystem_transfer_store.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import 'ecosystem_inbox_page.dart';

final class EcosystemAppDetailPage extends StatelessWidget {
  const EcosystemAppDetailPage({
    super.key,
    required this.appId,
  });

  final EcosystemAppId appId;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final services = WonderlogServicesScope.of(context);
    final definition = EcosystemRegistry.definition(appId);

    return Scaffold(
      appBar: AppBar(title: Text(definition.displayName)),
      body: StreamBuilder<List<EcosystemInboxItem>>(
        stream: services.ecosystemTransferStore.watchInboxHistory(),
        builder: (context, inboxSnapshot) {
          return StreamBuilder<List<EcosystemOutboxItem>>(
            stream: services.ecosystemTransferStore.watchOutboxHistory(),
            builder: (context, outboxSnapshot) {
              if (!inboxSnapshot.hasData || !outboxSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final received = inboxSnapshot.data!
                  .where((item) => item.sourceApp == appId)
                  .toList(growable: false);
              final sent = outboxSnapshot.data!
                  .where((item) => item.targetApp == appId)
                  .toList(growable: false);
              final verified = received.isNotEmpty ||
                  sent.any((item) => item.deliveredAt != null);

              return ListView(
                padding: const EdgeInsets.all(WonderlogSpacing.medium),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WonderlogSpacing.medium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                      definition.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      verified
                                          ? strings.ecosystemConnectedApp
                                          : strings.ecosystemConfiguredApp,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                verified
                                    ? Icons.verified_outlined
                                    : Icons.settings_ethernet_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: WonderlogSpacing.medium),
                          Row(
                            children: [
                              Expanded(
                                child: _Metric(
                                  label: strings.ecosystemReceivedCount,
                                  value: received.length,
                                ),
                              ),
                              Expanded(
                                child: _Metric(
                                  label: strings.ecosystemSentCount,
                                  value: sent.length,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WonderlogSpacing.medium),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WonderlogSpacing.medium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.ecosystemCapabilities,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: WonderlogSpacing.small),
                          Wrap(
                            spacing: WonderlogSpacing.xSmall,
                            runSpacing: WonderlogSpacing.xSmall,
                            children: definition.capabilities
                                .map(
                                  (capability) => Chip(
                                    avatar: Icon(
                                      _capabilityIcon(capability),
                                      size: 16,
                                    ),
                                    label: Text(
                                      _capabilityLabel(capability),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WonderlogSpacing.medium),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EcosystemInboxPage(),
                      ),
                    ),
                    icon: const Icon(Icons.inbox_outlined),
                    label: Text(strings.ecosystemInboxOpen),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static IconData _capabilityIcon(EcosystemCapability capability) =>
      switch (capability) {
        EcosystemCapability.receiveText => Icons.notes_outlined,
        EcosystemCapability.receivePhoto => Icons.photo_outlined,
        EcosystemCapability.receivePlace => Icons.place_outlined,
        EcosystemCapability.receiveJourney => Icons.luggage_outlined,
        EcosystemCapability.receiveRoute => Icons.route_outlined,
      };

  static String _capabilityLabel(EcosystemCapability capability) =>
      switch (capability) {
        EcosystemCapability.receiveText => 'Text',
        EcosystemCapability.receivePhoto => 'Photo',
        EcosystemCapability.receivePlace => 'Place',
        EcosystemCapability.receiveJourney => 'Journey',
        EcosystemCapability.receiveRoute => 'Route',
      };
}

final class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      );
}
