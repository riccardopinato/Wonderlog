import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/ecosystem_transfer_service.dart';
import '../../../core/ecosystem/wonderlog_ecosystem_adapter.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';
import 'memory_editor_page.dart';

final class MemoryDetailPage extends StatelessWidget {
  const MemoryDetailPage({
    super.key,
    required this.repository,
    required this.memoryId,
  });

  final WonderlogRepository repository;
  final String memoryId;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return StreamBuilder<MemoryWithPhotos?>(
      stream: repository.watchMemory(memoryId),
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(strings.memoryUnavailable)),
          );
        }

        final memory = item.memory;
        final locale = Localizations.localeOf(context).toLanguageTag();

        return Scaffold(
          appBar: AppBar(
            title: Text(strings.memoryDetail),
            actions: [
              PopupMenuButton<EcosystemTransferMode>(
                tooltip: strings.lifeBridgeShareToAnna,
                icon: const Icon(Icons.hub_outlined),
                onSelected: (mode) => _shareToAnna(
                  context,
                  item,
                  mode,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: EcosystemTransferMode.copy,
                    child: Text(strings.lifeBridgeCopyToAnna),
                  ),
                  PopupMenuItem(
                    value: EcosystemTransferMode.link,
                    child: Text(strings.lifeBridgeLinkToAnna),
                  ),
                ],
              ),
              IconButton(
                tooltip: strings.memoryEdit,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MemoryEditorPage(
                      repository: repository,
                      journeyId: memory.journeyId,
                      isPremium: () =>
                          WonderlogServicesScope.of(context).controller.isPremium,
                      existing: memory,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            children: [
              Text(
                memory.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: WonderlogSpacing.small),
              Wrap(
                spacing: WonderlogSpacing.small,
                runSpacing: WonderlogSpacing.xSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(label: Text(memory.mood.emoji + ' ' + memory.mood.label)),
                  Chip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(DateFormat.yMMMd(locale).format(memory.date)),
                  ),
                  if (memory.locationName.trim().isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.place_outlined, size: 16),
                      label: Text(memory.locationName),
                    ),
                ],
              ),
              if (memory.journalText.trim().isNotEmpty) ...[
                const SizedBox(height: WonderlogSpacing.large),
                Text(
                  strings.memoryJournal,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: WonderlogSpacing.small),
                Text(
                  memory.journalText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                      ),
                ),
              ],
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: WonderlogSpacing.large),
                Wrap(
                  spacing: WonderlogSpacing.xSmall,
                  runSpacing: WonderlogSpacing.xSmall,
                  children: memory.tags
                      .map((tag) => Chip(label: Text('#' + tag)))
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: WonderlogSpacing.large),
              Text(
                strings.memoryPhotos,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: WonderlogSpacing.small),
              if (item.photos.isEmpty)
                Text(strings.memoryNoPhotos)
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.photos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: WonderlogSpacing.small),
                    itemBuilder: (context, index) {
                      final photo = item.photos[index];
                      return SizedBox(
                        width: 130,
                        child: Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(WonderlogSpacing.small),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_outlined, size: 34),
                                const SizedBox(height: 6),
                                Text(
                                  photo.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: WonderlogSpacing.large),
              Text(
                strings.memoryKeepsakes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: WonderlogSpacing.small),
              if (item.attachments.isEmpty)
                Text(strings.memoryNoKeepsakes)
              else
                ...item.attachments.map(
                  (attachment) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        attachment.originalName ??
                            strings.memoryKeepsakeDocument,
                      ),
                      subtitle: Text(attachment.mimeType),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareToAnna(
    BuildContext context,
    MemoryWithPhotos item,
    EcosystemTransferMode mode,
  ) async {
    final services = WonderlogServicesScope.of(context);
    final result = await services.ecosystemTransferService.send(
      targetApp: EcosystemAppId.annasDiary,
      envelope: WonderlogEcosystemAdapter.memory(
        item.memory,
        photos: item.photos,
        mode: mode,
      ),
    );
    if (!context.mounted) return;
    final strings = AppLocalizations.of(context);
    final message = switch (result.status) {
      EcosystemDeliveryStatus.openedTarget => strings.ecosystemOpenedAnna,
      EcosystemDeliveryStatus.fallbackCopied =>
        strings.lifeBridgeCopiedForAnna,
      EcosystemDeliveryStatus.unsupported =>
        strings.ecosystemUnsupportedAnna,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
