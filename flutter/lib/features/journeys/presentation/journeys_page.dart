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
    required this.isPremium,
  });

  final WonderlogRepository repository;
  final bool Function() isPremium;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.journeysTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateJourneyDialog(
          context,
          repository,
          isPremium: isPremium,
        ),
        icon: const Icon(Icons.add),
        label: Text(strings.addJourney),
      ),
      body: StreamBuilder<List<Journey>>(
        stream: repository.watchJourneys(),
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
                      strings.noJourneys,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: WonderlogSpacing.xSmall),
                    Text(
                      strings.noJourneysDescription,
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
      ),
    );
  }
}
