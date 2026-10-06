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
import 'rediscover_page.dart';

final class RediscoverHomeSection extends StatelessWidget {
  const RediscoverHomeSection({
    super.key,
    required this.repository,
    required this.journeys,
  });

  final WonderlogRepository repository;
  final List<Journey> journeys;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemoryWithPhotos>>(
      stream: repository.watchAllMemoriesWithPhotos(),
      builder: (context, memorySnapshot) {
        return StreamBuilder<List<AlbumPhotoEntry>>(
          stream: repository.watchAllPhotos(),
          builder: (context, photoSnapshot) {
            if (!memorySnapshot.hasData || !photoSnapshot.hasData) {
              return const SizedBox.shrink();
            }

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
              memories: RediscoverDataAdapter.memories(memoryBundles),
              photos: RediscoverDataAdapter.photos(photos),
            );
            final cards =
                RediscoverSelectionEngine.selectForHome(feed, maxCards: 5);
            if (cards.isEmpty) return const SizedBox.shrink();

            final strings = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: WonderlogSpacing.large),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.rediscoverTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RediscoverPage(
                            repository: repository,
                          ),
                        ),
                      ),
                      child: Text(strings.rediscoverSeeAll),
                    ),
                  ],
                ),
                const SizedBox(height: WonderlogSpacing.xSmall),
                Text(strings.rediscoverSubtitle),
                const SizedBox(height: WonderlogSpacing.small),
                SizedBox(
                  height: 166,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      width: WonderlogSpacing.small,
                    ),
                    itemBuilder: (context, index) => _RediscoverCard(
                      card: cards[index],
                      onTap: () => _open(context, cards[index]),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _open(BuildContext context, RediscoverCard card) {
    final memoryId = card.memoryId;
    if (memoryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MemoryDetailPage(
            repository: repository,
            memoryId: memoryId,
          ),
        ),
      );
      return;
    }

    final journeyId = card.journeyId;
    if (journeyId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JourneyDetailPage(
          repository: repository,
          journeyId: journeyId,
        ),
      ),
    );
  }
}

final class _RediscoverCard extends StatelessWidget {
  const _RediscoverCard({
    required this.card,
    required this.onTap,
  });

  final RediscoverCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.imageUri == null)
                  Icon(
                    switch (card.type) {
                      RediscoverType.journeyAnniversary =>
                        Icons.celebration_outlined,
                      RediscoverType.memory =>
                        Icons.auto_stories_outlined,
                      RediscoverType.photo => Icons.photo_outlined,
                      RediscoverType.onThisDay => Icons.history,
                    },
                    color: colors.primary,
                  )
                else
                  SizedBox(
                    height: 72,
                    width: double.infinity,
                    child: StoredMediaImage(
                      references: [card.imageUri!],
                      width: double.infinity,
                      height: 72,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                const Spacer(),
                Text(
                  card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if ((card.subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
