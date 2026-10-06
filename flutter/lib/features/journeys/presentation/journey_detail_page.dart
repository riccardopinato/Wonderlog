import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/picker/device_content_picker.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../export/application/journey_pdf_export_service.dart';
import '../../export/presentation/journey_pdf_export_page.dart';
import '../../map_memories/presentation/journey_map_page.dart';
import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../../memories/presentation/memory_editor_page.dart';
import '../../memories/presentation/photo_viewer_page.dart';
import '../../memories/presentation/stored_media_image.dart';
import '../../premium/domain/premium_gate.dart';
import '../../premium/presentation/premium_page.dart';
import '../../rediscover/domain/journey_replay_builder.dart';
import '../../rediscover/domain/rediscover_models.dart';
import '../../rediscover/presentation/journey_replay_page.dart';
import '../../timeline/presentation/timeline_page.dart';
import '../domain/journey.dart';
import 'journey_widgets.dart';

final class JourneyDetailPage extends StatelessWidget {
  const JourneyDetailPage({
    super.key,
    required this.repository,
    required this.journeyId,
  });

  final WonderlogRepository repository;
  final String journeyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Journey?>(
      stream: repository.watchJourney(journeyId),
      builder: (context, journeySnapshot) {
        final journey = journeySnapshot.data;
        if (journeySnapshot.connectionState == ConnectionState.waiting &&
            journey == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (journey == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(AppLocalizations.of(context).journeyUnavailable),
            ),
          );
        }

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(journey.title),
              bottom: TabBar(
                tabs: [
                  Tab(text: AppLocalizations.of(context).journeyOverview),
                  Tab(text: AppLocalizations.of(context).journeyMemories),
                  Tab(text: AppLocalizations.of(context).journeyAlbum),
                  Tab(text: AppLocalizations.of(context).journeyMap),
                  Tab(text: AppLocalizations.of(context).journeyTimeline),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: AppLocalizations.of(context).pdfTravelBookTitle,
                  onPressed: () => _openPdfExport(context, journey),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).journeyReplay,
                  onPressed: () => _openReplay(context, journey),
                  icon: const Icon(Icons.play_circle_outline),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleJourneyAction(context, journey, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(
                          AppLocalizations.of(context).journeyEdit,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          journey.archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(
                          journey.archived
                              ? AppLocalizations.of(context).journeyRestore
                              : AppLocalizations.of(context).journeyArchive,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_outline),
                        title: Text(AppLocalizations.of(context).delete),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: TabBarView(
              children: [
                _OverviewTab(journey: journey),
                _MemoriesTab(
                  repository: repository,
                  journeyId: journeyId,
                ),
                _AlbumTab(
                  repository: repository,
                  journeyId: journeyId,
                ),
                JourneyMapPage(
                  repository: repository,
                  journey: journey,
                ),
                TimelinePage(
                  repository: repository,
                  journey: journey,
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MemoryEditorPage(
                    repository: repository,
                    journeyId: journeyId,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).memoryAdd),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleJourneyAction(
    BuildContext context,
    Journey journey,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await showEditJourneyDialog(context, repository, journey);
        break;
      case 'archive':
        await repository.setJourneyArchived(
          journey.id,
          !journey.archived,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              journey.archived
                  ? AppLocalizations.of(context).journeyRestored
                  : AppLocalizations.of(context).journeyArchived,
            ),
          ),
        );
        Navigator.pop(context);
        break;
      case 'delete':
        await _deleteJourney(context, journey);
        break;
    }
  }

  Future<void> _deleteJourney(
    BuildContext context,
    Journey journey,
  ) async {
    final strings = AppLocalizations.of(context);
    final impact = await repository.getJourneyDeletionImpact(journey.id);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.journeyDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.journeyDeleteDescription),
            const SizedBox(height: WonderlogSpacing.small),
            Text(
              strings.journeyDeleteImpact(
                impact.memoryCount,
                impact.photoCount,
                impact.attachmentCount,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final photos = await repository.watchAlbum(journey.id).first;
    final memories =
        await repository.watchMemoriesWithPhotos(journey.id).first;
    final removedReferences = <String>{
      ...photos.map((photo) => photo.localUri),
      ...memories.expand(
        (item) =>
            item.attachments.map((attachment) => attachment.localUri),
      ),
    };

    await repository.deleteJourney(journey.id);
    final remaining = await repository.referencedMediaUris();
    final media = WonderlogServicesScope.of(context).photoImportService;
    for (final reference in removedReferences) {
      await media.deleteStoredReferenceIfUnreferenced(
        reference,
        remainingReferences: remaining,
      );
    }

    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _openPdfExport(
    BuildContext context,
    Journey journey,
  ) async {
    final services = WonderlogServicesScope.of(context);
    if (!services.controller.isPremium) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PremiumPage(
            service: services.controller.premiumService,
          ),
        ),
      );
      return;
    }

    final service = JourneyPdfExportService(
      repository: repository,
      photoImportService: services.photoImportService,
    );
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JourneyPdfExportPage(
          service: service,
          journeyId: journey.id,
        ),
      ),
    );
  }

  Future<void> _openReplay(
    BuildContext context,
    Journey journey,
  ) async {
    final memoryBundles =
        await repository.watchMemoriesWithPhotos(journey.id).first;
    final photos = await repository.watchAlbum(journey.id).first;
    if (!context.mounted) return;

    final replayJourney = RediscoverJourney(
      id: journey.id,
      title: journey.title,
      destination: journey.destination,
      startTimestamp: journey.startDate,
      endTimestamp: journey.endDate,
      coverPhotoUri: photos.isEmpty ? null : photos.first.localUri,
      photoCount: photos.length,
      memoryCount: memoryBundles.length,
    );

    final replay = const JourneyReplayBuilder().build(
      journey: replayJourney,
      photos: photos
          .map(
            (photo) => RediscoverPhoto(
              id: photo.id,
              journeyId: photo.journeyId,
              localUri: photo.localUri,
              timestamp: photo.capturedAt ?? photo.createdAt,
              locationName: photo.locationName,
            ),
          )
          .toList(growable: false),
      memories: memoryBundles
          .map(
            (item) => RediscoverMemory(
              id: item.memory.id,
              journeyId: item.memory.journeyId,
              title: item.memory.title,
              journalText: item.memory.journalText,
              timestamp: item.memory.date,
              locationName: item.memory.locationName,
              photoUris: item.photos
                  .map((photo) => photo.localUri)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JourneyReplayPage(replay: replay),
      ),
    );
  }
}

final class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final strings = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(WonderlogSpacing.medium),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WonderlogSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.destination,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: WonderlogSpacing.small),
                Text(
                  dateFormat.format(journey.startDate) +
                      ' – ' +
                      dateFormat.format(journey.endDate),
                ),
                if (journey.description.trim().isNotEmpty) ...[
                  const SizedBox(height: WonderlogSpacing.medium),
                  Text(journey.description),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: WonderlogSpacing.medium),
        Card(
          child: ListTile(
            leading: const Icon(Icons.offline_bolt_outlined),
            title: Text(strings.localFirstTitle),
            subtitle: Text(strings.localFirstDescription),
          ),
        ),
      ],
    );
  }
}

final class _MemoriesTab extends StatelessWidget {
  const _MemoriesTab({
    required this.repository,
    required this.journeyId,
  });

  final WonderlogRepository repository;
  final String journeyId;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);

    return StreamBuilder<List<MemoryWithPhotos>>(
      stream: repository.watchMemoriesWithPhotos(journeyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final memories = snapshot.data!;
        if (memories.isEmpty) {
          return Center(child: Text(strings.memoryEmpty));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            WonderlogSpacing.medium,
            WonderlogSpacing.medium,
            WonderlogSpacing.medium,
            100,
          ),
          itemCount: memories.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: WonderlogSpacing.small),
          itemBuilder: (context, index) {
            final item = memories[index];
            final memory = item.memory;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: SizedBox.square(
                  dimension: 52,
                  child: item.photos.isEmpty
                      ? CircleAvatar(child: Text(memory.mood.emoji))
                      : StoredMediaImage(
                          references: [
                            item.photos.first.thumbnailUri,
                            item.photos.first.localUri,
                            item.photos.first.originalUri,
                          ],
                          width: 52,
                          height: 52,
                          borderRadius: BorderRadius.circular(12),
                        ),
                ),
                title: Text(memory.title),
                subtitle: Text(
                  [
                    dateFormat.format(memory.date),
                    if (memory.locationName.trim().isNotEmpty)
                      memory.locationName,
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MemoryDetailPage(
                      repository: repository,
                      memoryId: memory.id,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

final class _AlbumTab extends StatefulWidget {
  const _AlbumTab({
    required this.repository,
    required this.journeyId,
  });

  final WonderlogRepository repository;
  final String journeyId;

  @override
  State<_AlbumTab> createState() => _AlbumTabState();
}

final class _AlbumTabState extends State<_AlbumTab> {
  final DeviceContentPicker _picker = const DeviceContentPicker();
  bool _importing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return StreamBuilder<List<AlbumPhotoEntry>>(
      stream: widget.repository.watchAlbum(widget.journeyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final photos = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WonderlogSpacing.medium,
                WonderlogSpacing.small,
                WonderlogSpacing.medium,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.albumPhotoCount(photos.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _importing
                        ? null
                        : () => _importPhotos(context, photos),
                    icon: _importing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(strings.albumImport),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(WonderlogSpacing.small),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: photos.isEmpty
                  ? Center(child: Text(strings.albumEmpty))
                  : GridView.builder(
                      padding: const EdgeInsets.all(WonderlogSpacing.medium),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: WonderlogSpacing.small,
                        crossAxisSpacing: WonderlogSpacing.small,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Tooltip(
                            message: photo.fileName,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PhotoViewerPage(
                                    repository: widget.repository,
                                    photo: photo,
                                  ),
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  StoredMediaImage(
                                    references: [
                                      photo.thumbnailUri,
                                      photo.localUri,
                                      photo.originalUri,
                                    ],
                                  ),
                                  Positioned(
                                    left: 6,
                                    right: 6,
                                    bottom: 6,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface
                                            .withValues(alpha: 0.84),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          photo.fileName.isEmpty
                                              ? strings.photo
                                              : photo.fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (photo.favorite)
                                    const Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Icon(Icons.favorite),
                                    ),
                                  if (photo.isCoverPhoto)
                                    const Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Icon(Icons.wallpaper_outlined),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importPhotos(
    BuildContext context,
    List<AlbumPhotoEntry> currentPhotos,
  ) async {
    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final incoming = await _picker.pickImages();
      if (incoming.isEmpty || !context.mounted) return;

      final services = WonderlogServicesScope.of(context);
      const gate = PremiumGate();
      final allowance = gate.calculatePhotoImportAllowance(
        currentPhotos.length,
        incoming.length,
        services.controller.isPremium,
      );

      if (allowance.allowedCount <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).albumLimit)),
          );
        }
        return;
      }

      final imported = <AlbumPhotoEntry>[...currentPhotos];
      var displayOrder = currentPhotos.length;

      for (final item in incoming.take(allowance.allowedCount)) {
        final uri = item.uri;
        if (uri == null || uri.trim().isEmpty) continue;
        try {
          final photo = await services.photoImportService.importPhoto(
            journeyId: widget.journeyId,
            sourceUri: uri,
            displayOrder: displayOrder,
            existingPhotos: imported,
            fileName: item.title,
            mimeType: item.mimeType,
          );
          await widget.repository.savePhoto(photo);
          imported.add(photo);
          displayOrder++;
        } on PhotoImportException catch (error) {
          _error = error.message;
        }
      }

      if (allowance.blockedCount > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).albumPartialImport(
                allowance.allowedCount,
                allowance.blockedCount,
              ),
            ),
          ),
        );
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}
