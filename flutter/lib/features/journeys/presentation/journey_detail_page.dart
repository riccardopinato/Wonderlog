import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../map_memories/presentation/journey_map_page.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../../memories/presentation/memory_editor_page.dart';
import '../../rediscover/domain/journey_replay_builder.dart';
import '../../rediscover/domain/rediscover_models.dart';
import '../../rediscover/presentation/journey_replay_page.dart';
import '../../timeline/presentation/timeline_page.dart';
import '../domain/journey.dart';

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
                  tooltip: AppLocalizations.of(context).journeyReplay,
                  onPressed: () => _openReplay(context, journey),
                  icon: const Icon(Icons.play_circle_outline),
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

  Future<void> _openReplay(
    BuildContext context,
    Journey journey,
  ) async {
    final memories = await repository.watchMemories(journey.id).first;
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
      memoryCount: memories.length,
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
      memories: memories
          .map(
            (memory) => RediscoverMemory(
              id: memory.id,
              journeyId: memory.journeyId,
              title: memory.title,
              journalText: memory.journalText,
              timestamp: memory.date,
              locationName: memory.locationName,
              photoUris: const [],
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

    return StreamBuilder<List<MemoryEntry>>(
      stream: repository.watchMemories(journeyId),
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
            final memory = memories[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(memory.mood.emoji)),
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

final class _AlbumTab extends StatelessWidget {
  const _AlbumTab({
    required this.repository,
    required this.journeyId,
  });

  final WonderlogRepository repository;
  final String journeyId;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return StreamBuilder<List<AlbumPhotoEntry>>(
      stream: repository.watchAlbum(journeyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final photos = snapshot.data!;
        if (photos.isEmpty) {
          return Center(child: Text(strings.albumEmpty));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(WonderlogSpacing.medium),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(WonderlogSpacing.small),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_outlined, size: 40),
                        const SizedBox(height: WonderlogSpacing.xSmall),
                        Text(
                          photo.fileName.isEmpty
                              ? strings.photo
                              : photo.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
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
