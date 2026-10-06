import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/ecosystem_registry.dart';
import '../../../core/ecosystem/ecosystem_transfer_store.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/presentation/journey_detail_page.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../application/ecosystem_inbox_materialization_service.dart';

final class EcosystemInboxPage extends StatelessWidget {
  const EcosystemInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final services = WonderlogServicesScope.of(context);
    final materializer = EcosystemInboxMaterializationService(
      repository: services.repository,
      store: services.ecosystemTransferStore,
      isPremium: () => services.controller.isPremium,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.ecosystemInboxTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: strings.ecosystemInboxPendingTab),
              Tab(text: strings.ecosystemInboxHistoryTab),
            ],
          ),
        ),
        body: StreamBuilder<List<EcosystemInboxItem>>(
          stream: services.ecosystemTransferStore.watchInboxHistory(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data!;
            final pending =
                all.where((item) => item.isPending).toList(growable: false);
            final history =
                all.where((item) => !item.isPending).toList(growable: false);

            return TabBarView(
              children: [
                _InboxList(
                  items: pending,
                  emptyText: strings.ecosystemInboxEmptyPending,
                  pending: true,
                  materializer: materializer,
                ),
                _InboxList(
                  items: history,
                  emptyText: strings.ecosystemInboxEmptyHistory,
                  pending: false,
                  materializer: materializer,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _InboxList extends StatelessWidget {
  const _InboxList({
    required this.items,
    required this.emptyText,
    required this.pending,
    required this.materializer,
  });

  final List<EcosystemInboxItem> items;
  final String emptyText;
  final bool pending;
  final EcosystemInboxMaterializationService materializer;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(WonderlogSpacing.large),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(WonderlogSpacing.medium),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) =>
          const SizedBox(height: WonderlogSpacing.small),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: WonderlogSpacing.xSmall,
            ),
            child: Text(
              strings.ecosystemInboxSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final item = items[index - 1];
        return _InboxItemCard(
          item: item,
          pending: pending,
          materializer: materializer,
        );
      },
    );
  }
}

final class _InboxItemCard extends StatefulWidget {
  const _InboxItemCard({
    required this.item,
    required this.pending,
    required this.materializer,
  });

  final EcosystemInboxItem item;
  final bool pending;
  final EcosystemInboxMaterializationService materializer;

  @override
  State<_InboxItemCard> createState() => _InboxItemCardState();
}

final class _InboxItemCardState extends State<_InboxItemCard> {
  bool _busy = false;

  EcosystemInboxItem get item => widget.item;
  bool get pending => widget.pending;
  EcosystemInboxMaterializationService get materializer => widget.materializer;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final source = EcosystemRegistry.definition(item.sourceApp).displayName;
    final envelope = item.envelope;
    final title = _title(item);
    final text = envelope.text?.trim() ?? '';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isLink = envelope.transferMode == EcosystemTransferMode.link;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.hub_outlined)),
                const SizedBox(width: WonderlogSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        DateFormat.yMMMd(locale)
                            .add_Hm()
                            .format(item.receivedAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    isLink ? Icons.link : Icons.copy_outlined,
                    size: 16,
                  ),
                  label: Text(isLink ? 'LINK' : 'COPY'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: WonderlogSpacing.small),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (text.isNotEmpty && text != title) ...[
              const SizedBox(height: WonderlogSpacing.xSmall),
              Text(
                text,
                maxLines: pending ? 5 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: WonderlogSpacing.small),
            Wrap(
              spacing: WonderlogSpacing.xSmall,
              runSpacing: WonderlogSpacing.xSmall,
              children: [
                Chip(
                  label: Text(envelope.sourceEntityType.name),
                  visualDensity: VisualDensity.compact,
                ),
                ...envelope.tags.take(3).map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: WonderlogSpacing.xSmall),
            Text(
              isLink
                  ? strings.ecosystemLinkMeaning
                  : strings.ecosystemCopyMeaning,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (pending) ...[
              const SizedBox(height: WonderlogSpacing.medium),
              Wrap(
                spacing: WonderlogSpacing.small,
                runSpacing: WonderlogSpacing.small,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _addToJourney(context),
                    icon: const Icon(Icons.luggage_outlined),
                    label: Text(strings.ecosystemAddExistingJourney),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _createJourney(context),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(strings.ecosystemCreateJourney),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _saveFreeMemory(context),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(strings.ecosystemSaveFreeMemory),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _ignore(context),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(strings.ecosystemIgnoreArchive),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: WonderlogSpacing.medium),
              Text(
                strings.ecosystemHistoryResult,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: WonderlogSpacing.xSmall),
              Text(_dispositionLabel(strings, item.disposition)),
              if (item.materializedMemoryId != null ||
                  item.materializedJourneyId != null) ...[
                const SizedBox(height: WonderlogSpacing.small),
                TextButton.icon(
                  onPressed: () => _openMaterialized(context),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(strings.open),
                ),
              ],
            ],
            if (isLink) ...[
              const SizedBox(height: WonderlogSpacing.xSmall),
              TextButton.icon(
                onPressed: _busy ? null : () => _openSource(context),
                icon: const Icon(Icons.link),
                label: Text(strings.ecosystemOpenSource),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addToJourney(BuildContext context) async {
    final services = WonderlogServicesScope.of(context);
    final strings = AppLocalizations.of(context);
    final journeys = await services.repository.watchJourneys().first;
    if (!context.mounted) return;
    if (journeys.isEmpty) {
      _message(context, strings.ecosystemNoJourneys);
      return;
    }

    final journeyId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(strings.ecosystemChooseJourney),
        children: [
          for (final journey in journeys)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, journey.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.luggage_outlined),
                title: Text(journey.title),
                subtitle: Text(journey.destination),
              ),
            ),
        ],
      ),
    );
    if (journeyId == null || !context.mounted) return;
    await _run(
      context,
      () => materializer.addToJourney(item, journeyId),
    );
  }

  Future<void> _createJourney(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final titleController = TextEditingController(text: _title(item));
    final firstPlace =
        item.envelope.places.isEmpty ? null : item.envelope.places.first;
    final firstPlaceName = firstPlace?.name.trim();
    final destinationController = TextEditingController(
      text: firstPlaceName != null && firstPlaceName.isNotEmpty
          ? firstPlaceName
          : _title(item),
    );

    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.ecosystemCreateJourneyTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: strings.journeyTitle),
              ),
              const SizedBox(height: WonderlogSpacing.small),
              TextField(
                controller: destinationController,
                decoration: InputDecoration(
                  labelText: strings.ecosystemJourneyDestination,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final destination = destinationController.text.trim();
                if (title.isEmpty || destination.isEmpty) return;
                Navigator.pop(dialogContext, [title, destination]);
              },
              child: Text(strings.create),
            ),
          ],
        ),
      );
      if (values == null || !context.mounted) return;
      final localDate = item.envelope.createdAtUtc.toLocal();
      final day = DateTime(localDate.year, localDate.month, localDate.day);
      await _run(
        context,
        () => materializer.createJourney(
          item: item,
          title: values[0],
          destination: values[1],
          startDate: day,
          endDate: day,
        ),
      );
    } finally {
      titleController.dispose();
      destinationController.dispose();
    }
  }

  Future<void> _saveFreeMemory(BuildContext context) =>
      _run(context, () => materializer.saveFreeMemory(item));

  Future<void> _ignore(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.ecosystemIgnoreArchive),
        content: Text(strings.ecosystemItemIgnored),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, () => materializer.ignore(item));
  }

  Future<void> _run(
    BuildContext context,
    Future<EcosystemInboxMaterializationResult> Function() operation,
  ) async {
    if (_busy) return;
    final strings = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await operation();
      if (!context.mounted) return;
      _message(context, strings.ecosystemActionDone);
    } on EcosystemInboxLimitException {
      if (!context.mounted) return;
      _message(context, strings.ecosystemPremiumLimit);
    } on EcosystemInboxAlreadyResolvedException {
      if (!context.mounted) return;
      _message(context, strings.ecosystemActionDone);
    } catch (_) {
      if (!context.mounted) return;
      _message(context, strings.ecosystemActionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSource(BuildContext context) async {
    final services = WonderlogServicesScope.of(context);
    final opened =
        await services.ecosystemTransferService.openSource(item.envelope);
    if (!context.mounted || opened) return;
    _message(context, AppLocalizations.of(context).ecosystemNotAvailable);
  }

  void _openMaterialized(BuildContext context) {
    final services = WonderlogServicesScope.of(context);
    final memoryId = item.materializedMemoryId;
    if (memoryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MemoryDetailPage(
            repository: services.repository,
            memoryId: memoryId,
          ),
        ),
      );
      return;
    }
    final journeyId = item.materializedJourneyId;
    if (journeyId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => JourneyDetailPage(
            repository: services.repository,
            journeyId: journeyId,
          ),
        ),
      );
    }
  }

  static String _title(EcosystemInboxItem item) {
    final explicit = item.envelope.title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final line in item.envelope.fallback.plainText.split(RegExp(r'[\r\n]+'))) {
      if (line.trim().isNotEmpty) return line.trim();
    }
    return item.envelope.sourceEntityType.name;
  }

  static String _dispositionLabel(
    AppLocalizations strings,
    EcosystemInboxDisposition value,
  ) =>
      switch (value) {
        EcosystemInboxDisposition.addedToJourney =>
          strings.ecosystemInboxDispositionAddedToJourney,
        EcosystemInboxDisposition.createdJourney =>
          strings.ecosystemInboxDispositionCreatedJourney,
        EcosystemInboxDisposition.savedFreeMemory =>
          strings.ecosystemInboxDispositionSavedFreeMemory,
        EcosystemInboxDisposition.ignored =>
          strings.ecosystemInboxDispositionIgnored,
        EcosystemInboxDisposition.seenLegacy =>
          strings.ecosystemInboxDispositionSeenLegacy,
        EcosystemInboxDisposition.pending =>
          strings.ecosystemInboxPendingTab,
      };

  static void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
