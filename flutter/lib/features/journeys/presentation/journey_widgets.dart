import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/ecosystem_transfer_service.dart';
import '../../../core/ecosystem/wonderlog_ecosystem_adapter.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journey.dart';
import '../domain/journey_repository.dart';

final class JourneyCard extends StatelessWidget {
  const JourneyCard({
    super.key,
    required this.journey,
    this.onOpen,
  });

  final Journey journey;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(WonderlogRadii.small),
              ),
              child: Icon(
                Icons.flight_takeoff,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: WonderlogSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journey.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    journey.destination,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormat.format(journey.startDate)} – ${dateFormat.format(journey.endDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: WonderlogSpacing.xSmall),
            PopupMenuButton<EcosystemTransferMode>(
              tooltip: strings.lifeBridgeShareToAnna,
              icon: const Icon(Icons.hub_outlined),
              onSelected: (mode) async {
                final services = WonderlogServicesScope.of(context);
                final result = await services.ecosystemTransferService.send(
                  targetApp: EcosystemAppId.annasDiary,
                  envelope: WonderlogEcosystemAdapter.journey(
                    journey,
                    mode: mode,
                  ),
                );
                if (!context.mounted) return;
                final message = switch (result.status) {
                  EcosystemDeliveryStatus.openedTarget =>
                    strings.ecosystemOpenedAnna,
                  EcosystemDeliveryStatus.fallbackCopied =>
                    strings.lifeBridgeCopiedForAnna,
                  EcosystemDeliveryStatus.unsupported =>
                    strings.ecosystemUnsupportedAnna,
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: EcosystemTransferMode.copy,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_all_outlined),
                    title: Text(strings.lifeBridgeCopyToAnna),
                  ),
                ),
                PopupMenuItem(
                  value: EcosystemTransferMode.link,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_outlined),
                    title: Text(strings.lifeBridgeLinkToAnna),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

Future<void> showCreateJourneyDialog(
  BuildContext context,
  JourneyRepository repository,
) async {
  final strings = AppLocalizations.of(context);
  final titleController = TextEditingController();
  final destinationController = TextEditingController();
  var startDate = DateTime.now();
  var endDate = DateTime.now();

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final locale = Localizations.localeOf(context).toLanguageTag();
          final formatter = DateFormat.yMMMd(locale);

          Future<void> pickStart() async {
            final value = await showDatePicker(
              context: context,
              initialDate: startDate,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (value == null) return;
            setDialogState(() {
              startDate = value;
              if (endDate.isBefore(startDate)) endDate = startDate;
            });
          }

          Future<void> pickEnd() async {
            final value = await showDatePicker(
              context: context,
              initialDate: endDate,
              firstDate: startDate,
              lastDate: DateTime(2200),
            );
            if (value == null) return;
            setDialogState(() => endDate = value);
          }

          return AlertDialog(
            title: Text(strings.newJourney),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: strings.journeyTitle),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: WonderlogSpacing.small),
                  TextField(
                    controller: destinationController,
                    decoration:
                        InputDecoration(labelText: strings.destination),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: WonderlogSpacing.medium),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.startDate),
                    subtitle: Text(formatter.format(startDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.endDate),
                    subtitle: Text(formatter.format(endDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: pickEnd,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final destination = destinationController.text.trim();
                  if (title.isEmpty || destination.isEmpty) return;

                  await repository.createJourney(
                    title: title,
                    destination: destination,
                    startDate: startDate,
                    endDate: endDate,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text(strings.save),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    titleController.dispose();
    destinationController.dispose();
  }
}
