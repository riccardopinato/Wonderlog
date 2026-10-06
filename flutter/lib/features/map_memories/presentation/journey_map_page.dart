import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/domain/journey.dart';
import '../../location/domain/location_models.dart';
import '../../location/domain/offline_map_service.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../premium/domain/premium_gate.dart';
import '../../premium/presentation/premium_page.dart';
import '../../smart_journey/domain/geo_math.dart';
import '../application/journey_map_data_adapter.dart';
import '../domain/journey_replay_path_builder.dart';
import '../domain/map_cluster_engine.dart';
import '../domain/map_memory_filter.dart';
import '../domain/map_memory_models.dart';

enum _PathMode {
  replay,
  road,
}

final class JourneyMapPage extends StatefulWidget {
  const JourneyMapPage({
    super.key,
    required this.repository,
    required this.journey,
  });

  final WonderlogRepository repository;
  final Journey journey;

  @override
  State<JourneyMapPage> createState() => _JourneyMapPageState();
}

final class _JourneyMapPageState extends State<JourneyMapPage> {
  MapMemoryFilterState _filter = const MapMemoryFilterState();
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  String? _renderSignature;
  List<MapMemoryCluster> _renderedClusters = const [];
  _PathMode _pathMode = _PathMode.replay;
  List<MapCoordinate>? _roadPath;
  bool _roadRouting = false;
  double _offlineProgress = 0;
  bool _offlineBusy = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemoryEntry>>(
      stream: widget.repository.watchMemories(widget.journey.id),
      builder: (context, memorySnapshot) {
        return StreamBuilder<List<AlbumPhotoEntry>>(
          stream: widget.repository.watchAlbum(widget.journey.id),
          builder: (context, photoSnapshot) {
            if (!memorySnapshot.hasData || !photoSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = JourneyMapDataAdapter.build(
              journey: widget.journey,
              memories: memorySnapshot.data!,
              photos: photoSnapshot.data!,
            );
            final filtered = MapMemoryFilter.apply(items, _filter);
            final clusters = const MapClusterEngine().cluster(filtered);
            final replay = const JourneyReplayPathBuilder().build(clusters);
            final displayedPath = _pathMode == _PathMode.road &&
                    _roadPath != null
                ? _roadPath!
                : replay.map((point) => point.coordinate).toList(growable: false);
            final strings = AppLocalizations.of(context);

            if (items.isEmpty) {
              return Center(child: Text(strings.mapEmpty));
            }

            final center = clusters.isNotEmpty
                ? clusters.first.coordinate
                : items.first.coordinate;
            final dayIndexes = items
                .map((item) => item.dayIndex)
                .whereType<int>()
                .toSet()
                .toList()
              ..sort();

            _scheduleMapRender(
              context,
              clusters: clusters,
              path: displayedPath,
            );

            final services = WonderlogServicesScope.of(context);
            final routingAvailable = services.roadRoutingService.configured;

            return Stack(
              children: [
                MapLibreMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(center.latitude, center.longitude),
                    zoom: 11,
                  ),
                  styleString: AppConfig.current.mapStyleUrl,
                  compassEnabled: true,
                  logoEnabled: false,
                  attributionButtonPosition:
                      AttributionButtonPosition.bottomRight,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: () {
                    _styleLoaded = true;
                    _renderSignature = null;
                    setState(() {});
                  },
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Card(
                      margin: const EdgeInsets.all(WonderlogSpacing.small),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.all(WonderlogSpacing.xSmall),
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(strings.mapAll),
                              selected: _filter.selectedDayIndex == null,
                              onSelected: (_) => _setFilter(
                                MapMemoryFilterState(
                                  contentFilter: _filter.contentFilter,
                                ),
                              ),
                            ),
                            for (final day in dayIndexes) ...[
                              const SizedBox(width: 6),
                              FilterChip(
                                label: Text((day + 1).toString()),
                                selected: _filter.selectedDayIndex == day,
                                onSelected: (_) => _setFilter(
                                  MapMemoryFilterState(
                                    selectedDayIndex: day,
                                    contentFilter: _filter.contentFilter,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: WonderlogSpacing.small),
                            SegmentedButton<MapMemoryContentFilter>(
                              segments: [
                                ButtonSegment(
                                  value: MapMemoryContentFilter.all,
                                  label: Text(strings.mapAll),
                                ),
                                ButtonSegment(
                                  value: MapMemoryContentFilter.photos,
                                  label: Text(strings.mapPhotos),
                                ),
                                ButtonSegment(
                                  value: MapMemoryContentFilter.memories,
                                  label: Text(strings.mapMemories),
                                ),
                              ],
                              selected: {_filter.contentFilter},
                              onSelectionChanged: (values) => _setFilter(
                                MapMemoryFilterState(
                                  selectedDayIndex: _filter.selectedDayIndex,
                                  contentFilter: values.single,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(WonderlogSpacing.small),
                      child: Card(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(WonderlogSpacing.small),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (routingAvailable)
                                    SegmentedButton<_PathMode>(
                                      segments: [
                                        ButtonSegment(
                                          value: _PathMode.replay,
                                          icon: const Icon(
                                            Icons.timeline_outlined,
                                          ),
                                          label: Text(
                                            strings.mapReplayPathShort,
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: _PathMode.road,
                                          icon: const Icon(
                                            Icons.alt_route_outlined,
                                          ),
                                          label: Text(
                                            strings.mapRoadRouteShort,
                                          ),
                                        ),
                                      ],
                                      selected: {_pathMode},
                                      onSelectionChanged: (selection) =>
                                          _setPathMode(
                                        context,
                                        selection.single,
                                        replay,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.timeline_outlined),
                                  const SizedBox(
                                    width: WonderlogSpacing.small,
                                  ),
                                  Flexible(
                                    child: Text(
                                      _pathMode == _PathMode.road
                                          ? strings.mapRoadRouteTruth
                                          : strings.mapReplayPathTruth,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_roadRouting) ...[
                                    const SizedBox(
                                      width: WonderlogSpacing.small,
                                    ),
                                    const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(
                                    width: WonderlogSpacing.small,
                                  ),
                                  IconButton(
                                    tooltip: strings.offlineMapsTitle,
                                    onPressed: _offlineBusy
                                        ? null
                                        : () => _openOfflineSheet(
                                              context,
                                              clusters,
                                            ),
                                    icon: const Icon(
                                      Icons.download_for_offline_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              if (_offlineBusy)
                                LinearProgressIndicator(
                                  value: _offlineProgress > 0
                                      ? _offlineProgress
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 8,
                  bottom: 4,
                  child: IgnorePointer(
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10),
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

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onCircleTapped.add((circle) {
      final clusterId = circle.data?['clusterId']?.toString();
      if (clusterId == null) return;
      for (final cluster in _renderedClusters) {
        if (cluster.id == clusterId) {
          _showCluster(context, cluster);
          return;
        }
      }
    });
  }

  void _setFilter(MapMemoryFilterState filter) {
    setState(() {
      _filter = filter;
      _pathMode = _PathMode.replay;
      _roadPath = null;
      _renderSignature = null;
    });
  }

  Future<void> _setPathMode(
    BuildContext context,
    _PathMode mode,
    List<JourneyRoutePoint> replay,
  ) async {
    if (mode == _PathMode.replay) {
      setState(() {
        _pathMode = mode;
        _roadPath = null;
        _renderSignature = null;
      });
      return;
    }

    final routing = WonderlogServicesScope.of(context).roadRoutingService;
    if (!routing.configured || replay.length < 2) return;

    setState(() {
      _pathMode = _PathMode.road;
      _roadRouting = true;
      _roadPath = null;
      _renderSignature = null;
    });

    try {
      final result = await routing.route(replay);
      if (!context.mounted) return;
      if (result == null) {
        setState(() => _pathMode = _PathMode.replay);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).mapRoadRouteFailed)),
        );
        return;
      }
      setState(() {
        _roadPath = result.points;
        _renderSignature = null;
      });
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _pathMode = _PathMode.replay);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).mapRoadRouteFailed)),
      );
    } finally {
      if (mounted) setState(() => _roadRouting = false);
    }
  }

  void _scheduleMapRender(
    BuildContext context, {
    required List<MapMemoryCluster> clusters,
    required List<MapCoordinate> path,
  }) {
    if (!_styleLoaded || _mapController == null) return;
    final signature = [
      _pathMode.name,
      ...clusters.map(
        (cluster) =>
            '${cluster.id}:${cluster.count}:${cluster.coordinate.latitude}:${cluster.coordinate.longitude}',
      ),
      'path',
      ...path.map(
        (point) => '${point.latitude}:${point.longitude}',
      ),
    ].join('|');
    if (signature == _renderSignature) return;
    _renderSignature = signature;

    final primary = Theme.of(context).colorScheme.primary;
    final primaryHex = _colorHex(primary);
    _renderedClusters = clusters;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = _mapController;
      if (!mounted || controller == null || !_styleLoaded) return;
      await controller.clearLines();
      await controller.clearCircles();
      await controller.clearSymbols();

      if (path.length > 1) {
        await controller.addLine(
          LineOptions(
            geometry: path
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(growable: false),
            lineColor: primaryHex,
            lineWidth: _pathMode == _PathMode.road ? 5 : 4,
            lineOpacity: _pathMode == _PathMode.road ? 0.95 : 0.78,
          ),
          {'pathMode': _pathMode.name},
        );
      }

      if (clusters.isEmpty) return;
      await controller.addCircles(
        clusters
            .map(
              (cluster) => CircleOptions(
                geometry: LatLng(
                  cluster.coordinate.latitude,
                  cluster.coordinate.longitude,
                ),
                circleRadius: 20,
                circleColor: primaryHex,
                circleStrokeWidth: 2,
                circleStrokeColor: '#FFFFFF',
              ),
            )
            .toList(growable: false),
        clusters
            .map((cluster) => {'clusterId': cluster.id})
            .toList(growable: false),
      );
      await controller.addSymbols(
        clusters
            .map(
              (cluster) => SymbolOptions(
                geometry: LatLng(
                  cluster.coordinate.latitude,
                  cluster.coordinate.longitude,
                ),
                textField: cluster.count.toString(),
                textSize: 13,
                textColor: '#FFFFFF',
                textHaloColor: primaryHex,
                textHaloWidth: 0.5,
                zIndex: 10,
              ),
            )
            .toList(growable: false),
      );
    });
  }

  Future<void> _openOfflineSheet(
    BuildContext context,
    List<MapMemoryCluster> clusters,
  ) async {
    final strings = AppLocalizations.of(context);
    final services = WonderlogServicesScope.of(context);
    final access = services.premiumAccessPolicy
        .canUseFeature(PremiumFeature.offlineMaps);

    if (access is! PremiumAllowed) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PremiumPage(
            service: services.controller.premiumService,
          ),
        ),
      );
      return;
    }

    final availability = services.offlineMapService.availability;
    if (availability == OfflineMapAvailability.unsupportedPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.offlineMapsNativeOnly)),
      );
      return;
    }
    if (availability == OfflineMapAvailability.providerNotConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.offlineMapsProviderUnavailable)),
      );
      return;
    }

    final proposed = _offlineRegionFor(clusters);
    final currentRegions =
        await services.locationRepository.watchOfflineRegions().first;
    OfflineMapRegion existing = proposed;
    for (final region in currentRegions) {
      if (region.id == proposed.id) {
        existing = region;
        break;
      }
    }

    final nativeDownloaded =
        await services.offlineMapService.isDownloaded(proposed.id);
    if (nativeDownloaded != existing.isDownloaded) {
      existing = existing.copyWith(
        isDownloaded: nativeDownloaded,
        downloadProgress: nativeDownloaded ? 1 : 0,
        sizeBytes: nativeDownloaded ? existing.sizeBytes : 0,
      );
      await services.locationRepository.saveOfflineRegion(existing);
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          WonderlogSpacing.medium,
          0,
          WonderlogSpacing.medium,
          WonderlogSpacing.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.offlineMapsTitle,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: WonderlogSpacing.small),
            Text(
              strings.offlineMapsRegionDescription(
                existing.radiusKm.toStringAsFixed(1),
                existing.zoomMin,
                existing.zoomMax,
              ),
            ),
            if (existing.isDownloaded) ...[
              const SizedBox(height: WonderlogSpacing.small),
              Text(strings.offlineMapsReady),
            ],
            const SizedBox(height: WonderlogSpacing.medium),
            if (existing.isDownloaded)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _deleteOfflineRegion(context, existing);
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.offlineMapsDelete),
              )
            else
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _downloadOfflineRegion(context, existing);
                },
                icon: const Icon(Icons.download_for_offline_outlined),
                label: Text(strings.offlineMapsDownload),
              ),
          ],
        ),
      ),
    );
  }

  OfflineMapRegion _offlineRegionFor(List<MapMemoryCluster> clusters) {
    var centerLatitude = widget.journey.latitude;
    var centerLongitude = widget.journey.longitude;

    if (clusters.isNotEmpty) {
      centerLatitude = clusters
              .map((cluster) => cluster.coordinate.latitude)
              .reduce((a, b) => a + b) /
          clusters.length;
      centerLongitude = clusters
              .map((cluster) => cluster.coordinate.longitude)
              .reduce((a, b) => a + b) /
          clusters.length;
    }

    var farthestMeters = 0.0;
    for (final cluster in clusters) {
      final distance = GeoMath.distanceMeters(
        centerLatitude,
        centerLongitude,
        cluster.coordinate.latitude,
        cluster.coordinate.longitude,
      );
      if (distance > farthestMeters) farthestMeters = distance;
    }

    final radiusKm = ((farthestMeters / 1000) * 1.25).clamp(2.0, 50.0);
    return OfflineMapRegion(
      id: 'journey_${widget.journey.id}',
      name: widget.journey.title,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radiusKm: radiusKm,
      zoomMin: 8,
      zoomMax: 15,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _downloadOfflineRegion(
    BuildContext context,
    OfflineMapRegion region,
  ) async {
    final services = WonderlogServicesScope.of(context);
    setState(() {
      _offlineBusy = true;
      _offlineProgress = 0;
    });
    await services.locationRepository.saveOfflineRegion(region);

    try {
      final downloaded = await services.offlineMapService.download(
        region,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _offlineProgress = progress.fraction);
        },
      );
      await services.locationRepository.saveOfflineRegion(downloaded);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).offlineMapsDownloaded),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).offlineMapsDownloadFailed),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _offlineBusy = false;
          _offlineProgress = 0;
        });
      }
    }
  }

  Future<void> _deleteOfflineRegion(
    BuildContext context,
    OfflineMapRegion region,
  ) async {
    final services = WonderlogServicesScope.of(context);
    try {
      await services.offlineMapService.delete(region);
      await services.locationRepository.deleteOfflineRegion(region.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).offlineMapsDeleted),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).offlineMapsDeleteFailed),
        ),
      );
    }
  }

  String _colorHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _showCluster(
    BuildContext context,
    MapMemoryCluster cluster,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          WonderlogSpacing.medium,
          0,
          WonderlogSpacing.medium,
          WonderlogSpacing.large,
        ),
        itemCount: cluster.items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = cluster.items[index];
          return ListTile(
            leading: Icon(
              item.type == MapMemoryItemType.photo
                  ? Icons.photo_outlined
                  : Icons.auto_stories_outlined,
            ),
            title: Text(
              (item.title ?? '').trim().isEmpty
                  ? AppLocalizations.of(context).appTitle
                  : item.title!,
            ),
            subtitle: (item.subtitle ?? '').trim().isEmpty
                ? null
                : Text(item.subtitle!),
          );
        },
      ),
    );
  }
}
