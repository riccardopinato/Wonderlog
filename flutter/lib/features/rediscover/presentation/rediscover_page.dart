import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/domain/journey.dart';
import '../../journeys/presentation/journey_detail_page.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../../memories/presentation/stored_media_image.dart';
import '../application/rediscover_data_adapter.dart';
import '../domain/rediscover_engine.dart';
import '../domain/rediscover_models.dart';
import '../domain/rediscover_selection_engine.dart';

enum RediscoverFilter { all, journeys, memories, photos }

final class RediscoverPage extends StatefulWidget {
  const RediscoverPage({
    super.key,
    required this.repository,
  });

  final WonderlogRepository repository;

  @override
  State<RediscoverPage> createState() => _RediscoverPageState();
}

final class _RediscoverPageState extends State<RediscoverPage> {
  RediscoverFilter _filter = RediscoverFilter.all;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.rediscoverTitle)),
      body: StreamBuilder<List<Journey>>(
        stream: widget.repository.watchJourneys(),
        builder: (context, journeySnapshot) {
          return StreamBuilder<List<MemoryWithPhotos>>(
            stream: widget.repository.watchAllMemoriesWithPhotos(),
            builder: (context, memorySnapshot) {
              return StreamBuilder<List<AlbumPhotoEntry>>(
                stream: widget.repository.watchAllPhotos(),
                builder: (context, photoSnapshot) {
                  if (!journeySnapshot.hasData ||
                      !memorySnapshot.hasData ||
                      !photoSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final journeys = journeySnapshot.data!;
                  final memoryBundles = memorySnapshot.data!;
                  final memories = memoryBundles
                      .map((item) => item.memory)
                      .toList(growable: false);
                  final photos = photoSnapshot.data!;
                  final feed = const RediscoverEngine().buildFeed(
                    today: DateTime.now(),
                    journeys: RediscoverDataAdapter.journeys(
                      journeys,
                      photos,
                      memories,
                    ),
                    memories:
                        RediscoverDataAdapter.memories(memoryBundles),
                    photos: RediscoverDataAdapter.photos(photos),
                  );

                  final allCards =
                      RediscoverSelectionEngine.selectForHome(
                    feed,
                    maxCards: 100,
                  );
                  final cards = allCards.where(_matchesFilter).toList();

                  return Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.all(WonderlogSpacing.small),
                        child: SegmentedButton<RediscoverFilter>(
                          segments: [
                            ButtonSegment(
                              value: RediscoverFilter.all,
                              label: Text(strings.rediscoverAll),
                            ),
                            ButtonSegment(
                              value: RediscoverFilter.journeys,
                              label: Text(strings.navJourneys),
                            ),
                            ButtonSegment(
                              value: RediscoverFilter.memories,
                              label: Text(strings.mapMemories),
                            ),
                            ButtonSegment(
                              value: RediscoverFilter.photos,
                              label: Text(strings.mapPhotos),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (value) {
                            setState(() => _filter = value.single);
                          },
                        ),
                      ),
                      Expanded(
                        child: cards.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    WonderlogSpacing.large,
                                  ),
                                  child: Text(
                                    strings.rediscoverEmpty,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  WonderlogSpacing.medium,
                                  WonderlogSpacing.small,
                                  WonderlogSpacing.medium,
                                  WonderlogSpacing.large,
                                ),
                                itemCount: cards.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(
                                  height: WonderlogSpacing.small,
                                ),
                                itemBuilder: (context, index) {
                                  final card = cards[index];
                                  return Card(
                                    child: ListTile(
                                      leading: SizedBox.square(
                                        dimension: 52,
                                        child: card.imageUri == null
                                            ? Icon(
                                                switch (card.type) {
                                                  RediscoverType
                                                          .journeyAnniversary =>
                                                    Icons
                                                        .celebration_outlined,
                                                  RediscoverType.memory =>
                                                    Icons
                                                        .auto_stories_outlined,
                                                  RediscoverType.photo =>
                                                    Icons.photo_outlined,
                                                  RediscoverType.onThisDay =>
                                                    Icons.history,
                                                },
                                              )
                                            : StoredMediaImage(
                                                references: [
                                                  card.imageUri!,
                                                ],
                                                width: 52,
                                                height: 52,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                      ),
                                      title: Text(card.title),
                                      subtitle:
                                          (card.subtitle ?? '').isEmpty
                                              ? null
                                              : Text(card.subtitle!),
                                      trailing:
                                          const Icon(Icons.chevron_right),
                                      onTap: () =>
                                          _open(context, card),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  bool _matchesFilter(RediscoverCard card) => switch (_filter) {
        RediscoverFilter.all => true,
        RediscoverFilter.journeys =>
          card.type == RediscoverType.journeyAnniversary,
        RediscoverFilter.memories =>
          card.type == RediscoverType.memory,
        RediscoverFilter.photos => card.type == RediscoverType.photo,
      };

  void _open(BuildContext context, RediscoverCard card) {
    final memoryId = card.memoryId;
    if (memoryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MemoryDetailPage(
            repository: widget.repository,
            memoryId: memoryId,
          ),
        ),
      );
      return;
    }

    final journeyId = card.journeyId;
    if (journeyId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => JourneyDetailPage(
            repository: widget.repository,
            journeyId: journeyId,
          ),
        ),
      );
    }
  }
}
