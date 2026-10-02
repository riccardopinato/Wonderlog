import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/domain/journey.dart';
import '../../journeys/domain/journey_repository.dart';
import '../../journeys/presentation/journey_widgets.dart';

final class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.journeyRepository,
  });

  final JourneyRepository journeyRepository;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: StreamBuilder<List<Journey>>(
        stream: journeyRepository.watchJourneys(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(strings.localDataError));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final journeys = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            children: [
              _TravelHero(
                journeyCount: journeys.length,
                onAdd: () => showCreateJourneyDialog(
                  context,
                  journeyRepository,
                ),
              ),
              const SizedBox(height: WonderlogSpacing.large),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.recentJourneys,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showCreateJourneyDialog(
                      context,
                      journeyRepository,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(strings.addJourney),
                  ),
                ],
              ),
              const SizedBox(height: WonderlogSpacing.small),
              if (journeys.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(WonderlogSpacing.large),
                    child: Column(
                      children: [
                        const Icon(Icons.travel_explore, size: 44),
                        const SizedBox(height: WonderlogSpacing.small),
                        Text(
                          strings.noJourneys,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: WonderlogSpacing.xSmall),
                        Text(
                          strings.noJourneysDescription,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...journeys
                    .take(3)
                    .map(
                      (journey) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: WonderlogSpacing.small,
                        ),
                        child: JourneyCard(journey: journey),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

final class _TravelHero extends StatelessWidget {
  const _TravelHero({
    required this.journeyCount,
    required this.onAdd,
  });

  final int journeyCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(WonderlogSpacing.large),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(WonderlogRadii.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.public,
            size: 42,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(height: WonderlogSpacing.large),
          Text(
            strings.homeHeadline,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: WonderlogSpacing.xSmall),
          Text(strings.homeDescription),
          const SizedBox(height: WonderlogSpacing.large),
          Wrap(
            spacing: WonderlogSpacing.small,
            runSpacing: WonderlogSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(strings.addJourney),
              ),
              Chip(
                avatar: const Icon(Icons.luggage_outlined, size: 18),
                label: Text(strings.journeyCount(journeyCount)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
