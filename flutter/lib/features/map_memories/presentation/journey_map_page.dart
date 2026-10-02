import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../journeys/domain/journey.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../application/journey_map_data_adapter.dart';
import '../domain/journey_route_builder.dart';
import '../domain/map_cluster_engine.dart';
import '../domain/map_memory_filter.dart';
import '../domain/map_memory_models.dart';

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
            final route = const JourneyRouteBuilder().build(clusters);
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

            return Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      center.latitude,
                      center.longitude,
                    ),
                    initialZoom: 11,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.riccardopinato.wonderlog',
                    ),
                    if (route.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route
                                .map(
                                  (point) => LatLng(
                                    point.coordinate.latitude,
                                    point.coordinate.longitude,
                                  ),
                                )
                                .toList(growable: false),
                            strokeWidth: 4,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: clusters
                          .map(
                            (cluster) => Marker(
                              point: LatLng(
                                cluster.coordinate.latitude,
                                cluster.coordinate.longitude,
                              ),
                              width: 52,
                              height: 52,
                              child: _ClusterMarker(
                                cluster: cluster,
                                onTap: () => _showCluster(context, cluster),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                        ),
                      ],
                    ),
                  ],
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Card(
                      margin: const EdgeInsets.all(WonderlogSpacing.small),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(WonderlogSpacing.xSmall),
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(strings.mapAll),
                              selected: _filter.selectedDayIndex == null,
                              onSelected: (_) => setState(
                                () => _filter = MapMemoryFilterState(
                                  contentFilter: _filter.contentFilter,
                                ),
                              ),
                            ),
                            for (final day in dayIndexes) ...[
                              const SizedBox(width: 6),
                              FilterChip(
                                label: Text((day + 1).toString()),
                                selected: _filter.selectedDayIndex == day,
                                onSelected: (_) => setState(
                                  () => _filter = MapMemoryFilterState(
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
                              onSelectionChanged: (values) => setState(
                                () => _filter = MapMemoryFilterState(
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
              ],
            );
          },
        );
      },
    );
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

final class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.cluster,
    required this.onTap,
  });

  final MapMemoryCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Text(
            cluster.count.toString(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}
