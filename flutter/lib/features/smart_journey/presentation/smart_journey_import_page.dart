import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/picker/device_content_picker.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../premium/presentation/premium_page.dart';
import '../../location/domain/location_repository.dart';
import '../application/smart_journey_integration_repository.dart';
import '../domain/smart_journey_models.dart';

final class SmartJourneyImportPage extends StatefulWidget {
  const SmartJourneyImportPage({
    super.key,
    required this.integration,
    required this.locationRepository,
    this.picker = const DeviceContentPicker(),
  });

  final SmartJourneyIntegrationRepository integration;
  final LocationRepository locationRepository;
  final DeviceContentPicker picker;

  @override
  State<SmartJourneyImportPage> createState() => _SmartJourneyImportPageState();
}

final class _SmartJourneyImportPageState extends State<SmartJourneyImportPage> {
  SmartJourneyDraft? _draft;
  SmartJourneyAnalysisProgress? _progress;
  SmartJourneyCreationAllowance? _allowance;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(title: Text(strings.smartJourneyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        children: [
          Text(
            strings.smartJourneyDescription,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: WonderlogSpacing.medium),
          FilledButton.icon(
            onPressed: _busy ? null : _pickAndAnalyse,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(strings.smartJourneyPickPhotos),
          ),
          if (_busy) ...[
            const SizedBox(height: WonderlogSpacing.medium),
            LinearProgressIndicator(value: _progress?.fraction),
          ],
          if (_error != null) ...[
            const SizedBox(height: WonderlogSpacing.medium),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (draft != null) ...[
            const SizedBox(height: WonderlogSpacing.large),
            Text(
              draft.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: WonderlogSpacing.xSmall),
            Text(
              draft.destination.trim().isEmpty
                  ? strings.smartJourneyDestinationUnknown
                  : draft.destination,
            ),
            const SizedBox(height: WonderlogSpacing.medium),
            Wrap(
              spacing: WonderlogSpacing.small,
              runSpacing: WonderlogSpacing.small,
              children: [
                Chip(
                  label: Text(
                    strings.smartJourneyPhotoCount(
                      draft.includedPhotos.length,
                    ),
                  ),
                ),
                Chip(
                  label: Text(strings.smartJourneyDayCount(draft.days.length)),
                ),
                Chip(
                  label: Text(strings.smartJourneyStopCount(draft.stopCount)),
                ),
              ],
            ),
            if (_allowance?.hasBlockedPhotos == true) ...[
              const SizedBox(height: WonderlogSpacing.medium),
              Text(
                strings.smartJourneyFreeLimit(
                  _allowance!.allowedPhotoCount,
                  _allowance!.blockedPhotoCount,
                ),
              ),
            ],
            if (_allowance?.hasBlockedMemories == true) ...[
              const SizedBox(height: WonderlogSpacing.medium),
              Text(strings.ecosystemPremiumLimit),
            ],
            if (_allowance?.requiresUpgrade == true) ...[
              const SizedBox(height: WonderlogSpacing.small),
              OutlinedButton.icon(
                onPressed: _busy ? null : _openPremium,
                icon: const Icon(Icons.star_outline),
                label: Text(strings.premiumTitle),
              ),
            ],
            const SizedBox(height: WonderlogSpacing.medium),
            ...draft.days.map(
              (day) => Card(
                child: ExpansionTile(
                  title: Text(day.title),
                  subtitle: Text(day.date.toIso8601String().split('T').first),
                  children: day.stops
                      .map(
                        (stop) => ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(stop.title),
                          subtitle: Text(
                            strings.smartJourneyStopPhotos(
                              stop.photoIds.length,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: WonderlogSpacing.large),
            FilledButton.icon(
              onPressed: _busy ||
                      _allowance == null ||
                      !_allowance!.journeyCreationAllowed ||
                      _allowance!.allowedPhotoCount <= 0 ||
                      _allowance!.hasBlockedMemories
                  ? null
                  : _createJourney,
              icon: const Icon(Icons.auto_awesome_motion_outlined),
              label: Text(strings.smartJourneyCreate),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndAnalyse() async {
    setState(() {
      _busy = true;
      _error = null;
      _draft = null;
      _allowance = null;
    });

    try {
      final photos = await widget.picker.pickSmartJourneyPhotos();
      if (photos.isEmpty) {
        setState(() => _busy = false);
        return;
      }

      final draft = await widget.integration.analysePhotos(
        photos: photos,
        resolvePlace: (latitude, longitude) async {
          final place = await widget.locationRepository.reverseGeocode(
            latitude,
            longitude,
          );
          return place?.displayName;
        },
        onProgress: (progress) async {
          if (mounted) setState(() => _progress = progress);
        },
      );
      final allowance =
          await widget.integration.evaluateCreationAllowance(draft);

      if (!mounted) return;
      setState(() {
        _draft = draft;
        _allowance = allowance;
        _busy = false;
        _progress = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = error.toString();
      });
    }
  }

  Future<void> _openPremium() async {
    final services = WonderlogServicesScope.of(context);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PremiumPage(
          service: services.controller.premiumService,
        ),
      ),
    );
    if (!mounted || _draft == null) return;
    final allowance =
        await widget.integration.evaluateCreationAllowance(_draft!);
    if (mounted) setState(() => _allowance = allowance);
  }

  Future<void> _createJourney() async {
    final draft = _draft;
    if (draft == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.integration.createJourneyFromDraft(draft);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }
}
