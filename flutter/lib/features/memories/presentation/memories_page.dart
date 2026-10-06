import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';
import 'memory_detail_page.dart';
import 'stored_media_image.dart';

enum MemoryLibraryFilter { all, unassigned }

final class MemoriesPage extends StatefulWidget {
  const MemoriesPage({
    super.key,
    required this.repository,
  });

  final WonderlogRepository repository;

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

final class _MemoriesPageState extends State<MemoriesPage> {
  MemoryLibraryFilter _filter = MemoryLibraryFilter.all;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.memoriesTitle)),
      body: StreamBuilder<List<MemoryWithPhotos>>(
        stream: widget.repository.watchAllMemoriesWithPhotos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(strings.localDataError));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final items = switch (_filter) {
            MemoryLibraryFilter.all => all,
            MemoryLibraryFilter.unassigned => all
                .where((item) => item.memory.journeyId == null)
                .toList(growable: false),
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(WonderlogSpacing.small),
                child: SegmentedButton<MemoryLibraryFilter>(
                  segments: [
                    ButtonSegment(
                      value: MemoryLibraryFilter.all,
                      icon: const Icon(Icons.auto_stories_outlined),
                      label: Text(strings.memoriesAll),
                    ),
                    ButtonSegment(
                      value: MemoryLibraryFilter.unassigned,
                      icon: const Icon(Icons.inbox_outlined),
                      label: Text(strings.memoriesUnassigned),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.single),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(WonderlogSpacing.large),
                          child: Text(
                            _filter == MemoryLibraryFilter.unassigned
                                ? strings.memoryUnassigned
                                : strings.memoryEmpty,
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
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(
                          height: WonderlogSpacing.small,
                        ),
                        itemBuilder: (context, index) => _MemoryLibraryCard(
                          item: items[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MemoryDetailPage(
                                repository: widget.repository,
                                memoryId: items[index].memory.id,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _MemoryLibraryCard extends StatelessWidget {
  const _MemoryLibraryCard({
    required this.item,
    required this.onTap,
  });

  final MemoryWithPhotos item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final memory = item.memory;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final subtitle = <String>[
      DateFormat.yMMMd(locale).format(memory.date),
      if (memory.locationName.trim().isNotEmpty) memory.locationName,
      if (memory.journeyId == null) strings.memoryUnassigned,
    ].join(' • ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: double.infinity,
                child: item.photos.isEmpty
                    ? ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        child: Center(
                          child: Text(
                            memory.mood.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      )
                    : StoredMediaImage(
                        references: [
                          item.photos.first.thumbnailUri,
                          item.photos.first.localUri,
                          item.photos.first.originalUri,
                        ],
                        width: 112,
                        height: double.infinity,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(WonderlogSpacing.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        memory.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: WonderlogSpacing.small),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
