import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../domain/journey.dart';
import 'journey_detail_page.dart';
import 'journey_widgets.dart';

final class JourneysPage extends StatelessWidget {
  const JourneysPage({
    super.key,
    required this.repository,
  });

  final WonderlogRepository repository;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.journeysTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: strings.journeysActive),
              Tab(text: strings.journeysArchived),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showCreateJourneyDialog(
            context,
            repository,
          ),
          icon: const Icon(Icons.add),
          label: Text(strings.addJourney),
        ),
        body: TabBarView(
          children: [
            _JourneyList(
              stream: repository.watchJourneys(),
              repository: repository,
              emptyTitle: strings.noJourneys,
              emptyDescription: strings.noJourneysDescription,
            ),
            _JourneyList(
              stream: repository.watchArchivedJourneys(),
              repository: repository,
              emptyTitle: strings.journeysArchived,
              emptyDescription: strings.noJourneys,
            ),
          ],
        ),
      ),
    );
  }
}

final class _JourneyList extends StatelessWidget {
  const _JourneyList({
    required this.stream,
    required this.repository,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final Stream<List<Journey>> stream;
  final WonderlogRepository repository;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return StreamBuilder<List<Journey>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(strings.localDataError));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final journeys = snapshot.data!;
        if (journeys.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(WonderlogSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.luggage_outlined, size: 48),
                  const SizedBox(height: WonderlogSpacing.small),
                  Text(
                    emptyTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: WonderlogSpacing.xSmall),
                  Text(
                    emptyDescription,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            WonderlogSpacing.medium,
            WonderlogSpacing.medium,
            WonderlogSpacing.medium,
            96,
          ),
          itemCount: journeys.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: WonderlogSpacing.small),
          itemBuilder: (context, index) {
            final journey = journeys[index];
            return JourneyCard(
              journey: journey,
              onOpen: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => JourneyDetailPage(
                    repository: repository,
                    journeyId: journey.id,
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
