import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/app_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/presentation/home_page.dart';
import '../../location/domain/location_repository.dart';
import '../../journeys/presentation/journeys_page.dart';
import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../profile/presentation/profile_page.dart';

final class WonderlogShell extends StatefulWidget {
  const WonderlogShell({
    super.key,
    required this.controller,
    required this.repository,
    required this.locationRepository,
    required this.photoImportService,
  });

  final AppController controller;
  final WonderlogRepository repository;
  final LocationRepository locationRepository;
  final PhotoImportService photoImportService;

  @override
  State<WonderlogShell> createState() => _WonderlogShellState();
}

final class _WonderlogShellState extends State<WonderlogShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final pages = <Widget>[
      HomePage(
        repository: widget.repository,
        isPremium: () => widget.controller.isPremium,
        locationRepository: widget.locationRepository,
        photoImportService: widget.photoImportService,
      ),
      JourneysPage(repository: widget.repository),
      ProfilePage(controller: widget.controller),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: strings.navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.luggage_outlined),
        selectedIcon: const Icon(Icons.luggage),
        label: strings.navJourneys,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: strings.navProfile,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= WonderlogLayout.railBreakpoint) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final item in destinations)
                        NavigationRailDestination(
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          label: Text(item.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _index,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: _index, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: destinations,
          ),
        );
      },
    );
  }

  void _select(int value) {
    if (value == _index) return;
    setState(() => _index = value);
  }
}
