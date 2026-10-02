import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/domain/journey.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../domain/timeline_engine.dart';
import '../domain/timeline_models.dart';

final class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.repository,
    required this.journey,
  });

  final WonderlogRepository repository;
  final Journey journey;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

final class _TimelinePageState extends State<TimelinePage> {
  TimelineSort _sort = TimelineSort.oldestFirst;
  TimelineFilter _filter = const TimelineFilter();

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return StreamBuilder<List<MemoryWithPhotos>>(
      stream: widget.repository.watchMemoriesWithPhotos(widget.journey.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = const TimelineEngine().generateTimeline(
          journey: widget.journey,
          memories: snapshot.data!,
          sort: _sort,
          filter: _filter,
          locale: Localizations.localeOf(context).toLanguageTag(),
        );

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(WonderlogSpacing.small),
              child: Row(
                children: [
                  DropdownButton<TimelineSort>(
                    value: _sort,
                    items: [
                      DropdownMenuItem(
                        value: TimelineSort.oldestFirst,
                        child: Text(strings.timelineOldest),
                      ),
                      DropdownMenuItem(
                        value: TimelineSort.newestFirst,
                        child: Text(strings.timelineNewest),
                      ),
                      DropdownMenuItem(
                        value: TimelineSort.favoritesFirst,
                        child: Text(strings.timelineFavorites),
                      ),
                      DropdownMenuItem(
                        value: TimelineSort.byMood,
                        child: Text(strings.timelineMood),
                      ),
                      DropdownMenuItem(
                        value: TimelineSort.byLocation,
                        child: Text(strings.timelineLocation),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                  const SizedBox(width: WonderlogSpacing.small),
                  FilterChip(
                    selected: _filter.showOnlyFavorites,
                    label: Text(strings.timelineFavorites),
                    onSelected: (value) => setState(
                      () => _filter = _filter.copyWith(
                        showOnlyFavorites: value,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    selected: _filter.hasPhotosOnly,
                    label: Text(strings.timelineWithPhotos),
                    onSelected: (value) => setState(
                      () => _filter = _filter.copyWith(
                        hasPhotosOnly: value,
                        noPhotosOnly: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: days.isEmpty
                  ? Center(child: Text(strings.timelineEmpty))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        WonderlogSpacing.medium,
                        WonderlogSpacing.small,
                        WonderlogSpacing.medium,
                        100,
                      ),
                      itemCount: days.length,
                      itemBuilder: (context, dayIndex) {
                        final day = days[dayIndex];
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: WonderlogSpacing.large,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.title,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                day.subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(
                                height: WonderlogSpacing.small,
                              ),
                              ...day.memories.map(
                                (item) => Card(
                                  child: ListTile(
                                    leading:
                                        CircleAvatar(child: Text(item.mood.emoji)),
                                    title: Text(item.title),
                                    subtitle: Text(
                                      item.journalPreview.isEmpty
                                          ? item.locationName
                                          : item.journalPreview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: item.favorite
                                        ? const Icon(Icons.favorite)
                                        : null,
                                    onTap: () => _openMemory(
                                      context,
                                      item.memoryId,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Future<void> _openMemory(
    BuildContext context,
    String memoryId,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MemoryDetailPage(
          repository: widget.repository,
          memoryId: memoryId,
        ),
      ),
    );
  }
}
