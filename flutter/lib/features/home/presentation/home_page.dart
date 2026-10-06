import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../capture/application/capture_controller.dart';
import '../../capture/data/wonderlog_capture_repository.dart';
import '../../capture/data/photo_capture_media_port.dart';
import '../../capture/presentation/capture_page.dart';
import '../../journeys/domain/journey.dart';
import '../../location/domain/location_repository.dart';
import '../../journeys/presentation/journey_detail_page.dart';
import '../../journeys/presentation/journey_widgets.dart';
import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../rediscover/presentation/rediscover_home_section.dart';
import '../../search/presentation/global_search_page.dart';
import '../../smart_journey/application/smart_journey_integration_repository.dart';
import '../../smart_journey/data/photo_import_service_smart_journey_adapter.dart';
import '../../smart_journey/presentation/smart_journey_import_page.dart';
import 'ecosystem_inbox_home_card.dart';

final class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.isPremium,
    required this.locationRepository,
    required this.photoImportService,
  });

  final WonderlogRepository repository;
  final bool Function() isPremium;
  final LocationRepository locationRepository;
  final PhotoImportService photoImportService;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final ecosystemStore =
        WonderlogServicesScope.maybeOf(context)?.ecosystemTransferStore;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.smartJourneyTitle,
            onPressed: () {
              final integration = SmartJourneyIntegrationRepository(
                repository: repository,
                photoImporter: PhotoImportServiceSmartJourneyAdapter(
                  photoImportService,
                ),
                isPremium: isPremium,
              );
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SmartJourneyImportPage(
                    integration: integration,
                    locationRepository: locationRepository,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_motion_outlined),
          ),
          IconButton(
            tooltip: strings.captureTitle,
            onPressed: () {
              final captureRepository = WonderlogCaptureRepository(
                repository: repository,
                mediaPort: PhotoCaptureMediaPort(
                  photoImportService: photoImportService,
                ),
                isPremium: isPremium,
              );
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CapturePage(
                    controller: CaptureController(captureRepository),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_box_outlined),
          ),
          IconButton(
            tooltip: strings.searchTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => GlobalSearchPage(repository: repository),
              ),
            ),
            icon: const Icon(Icons.search),
          ),
        ],
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
          return ListView(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            children: [
              _TravelHero(
                journeyCount: journeys.length,
                onAdd: () => showCreateJourneyDialog(
                  context,
                  repository,
                  isPremium: isPremium,
                ),
              ),
              if (ecosystemStore != null)
                EcosystemInboxHomeCard(store: ecosystemStore),
              RediscoverHomeSection(
                repository: repository,
                journeys: journeys,
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
                      repository,
                      isPremium: isPremium,
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
                ...journeys.take(3).map(
                      (journey) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: WonderlogSpacing.small,
                        ),
                        child: JourneyCard(
                          journey: journey,
                          onOpen: () => _openJourney(context, journey.id),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  void _openJourney(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JourneyDetailPage(
          repository: repository,
          journeyId: id,
        ),
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
