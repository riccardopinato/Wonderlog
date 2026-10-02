import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/domain/journey.dart';
import '../../journeys/presentation/journey_detail_page.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../domain/search_engine.dart';

final class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({
    super.key,
    required this.repository,
  });

  final WonderlogRepository repository;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

final class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: strings.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Journey>>(
              stream: widget.repository.watchJourneys(),
              builder: (context, journeySnapshot) {
                return StreamBuilder<List<MemoryEntry>>(
                  stream: widget.repository.watchAllMemories(),
                  builder: (context, memorySnapshot) {
                    if (!journeySnapshot.hasData || !memorySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final results = WonderlogSearchEngine.search(
                      query: _query,
                      journeys: journeySnapshot.data!,
                      memories: memorySnapshot.data!,
                    );

                    if (_query.trim().isEmpty) {
                      return Center(child: Text(strings.searchStartTyping));
                    }
                    if (results.isEmpty) {
                      return Center(child: Text(strings.searchNoResults));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        WonderlogSpacing.medium,
                        0,
                        WonderlogSpacing.medium,
                        WonderlogSpacing.large,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return switch (result) {
                          JourneySearchResult(:final journey) => ListTile(
                              leading: const Icon(Icons.luggage_outlined),
                              title: Text(journey.title),
                              subtitle: Text(journey.destination),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => JourneyDetailPage(
                                    repository: widget.repository,
                                    journeyId: journey.id,
                                  ),
                                ),
                              ),
                            ),
                          MemorySearchResult(:final memory) => ListTile(
                              leading:
                                  const Icon(Icons.auto_stories_outlined),
                              title: Text(memory.title),
                              subtitle: Text(
                                memory.locationName.trim().isEmpty
                                    ? memory.journalText
                                    : memory.locationName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => MemoryDetailPage(
                                    repository: widget.repository,
                                    memoryId: memory.id,
                                  ),
                                ),
                              ),
                            ),
                        };
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
