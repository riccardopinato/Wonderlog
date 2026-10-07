# MAXI STEP 26 — Maps / Offline Completion

Date: 2026-10-07

Baseline: `main @ 8c1f96f7337f1c12659ef5023a787cf555506bc8`

PR: #18 — `MAXI STEP 26: Maps / Offline Completion`

## Objective

Close three independent map gaps without conflating them:

1. chronological Journey replay vs real road routing;
2. real native offline map regions;
3. locale-aware geocoding and reverse geocoding.

The product must never call a chronological straight-line trace a road route,
never present an online cache as a guaranteed offline map, and never reuse
geocoding results across different app languages.

## Map engine

The Journey map renderer moves from `flutter_map` to
`maplibre_gl ^0.27.1`.

Reasons:
- Android, iOS and Web map rendering from one Flutter API;
- native Android/iOS offline-region APIs;
- permissive BSD-3-Clause package license;
- no need to adopt GPLv3 caching code in a proprietary monetized app.

CI now installs Java 21 before Flutter because the current MapLibre Android
plugin requires that toolchain level.

The obsolete direct `latlong2` dependency and the old
`JourneyRouteBuilder` source are removed.

## Replay truth

The former `JourneyRouteBuilder` behavior was not routing. It sorted
geotagged Memory/Photo clusters by timestamp and connected them.

It is now explicitly named:

`JourneyReplayPathBuilder`

Its contract is intentionally narrow:
- order geotagged clusters chronologically;
- collapse near-duplicate points;
- return a replay trace;
- never claim road/trail topology;
- never expose turn-by-turn semantics.

The map UI labels this mode **Replay** and states that it connects geotagged
content in time order rather than following roads.

## Real road routing boundary

A separate `RoadRoutingService` implements an OSRM-compatible HTTP contract.

Configuration:
- `WONDERLOG_ROUTING_URL`

Behavior:
- no hardcoded public/demo routing server;
- no network call when the endpoint is absent;
- UI exposes the **Roads** mode only when routing is configured;
- request uses `/route/v1/driving/<lon,lat;...>`;
- full GeoJSON overview is rendered as the road geometry;
- routing failure falls back to the chronological replay path with explicit
  user feedback.

This means replay truth is always available, while real road routing is an
explicit provider/infrastructure capability rather than a misleading local
polyline.

## Provider-safe online style

Configuration:
- `WONDERLOG_MAP_STYLE_URL`

The default online style is an OpenFreeMap MapLibre style. Standard
`tile.openstreetmap.org` raster tiles are no longer used by the Journey map.

OpenStreetMap attribution remains visible.

## Real offline regions

`MapLibreOfflineMapService` uses MapLibre native offline-region APIs on
Android/iOS.

Configuration:
- `WONDERLOG_OFFLINE_MAP_STYLE_URL`

The offline style is deliberately separate from the online fallback. It must
point to a provider/style whose terms explicitly permit the intended offline
download/caching behavior, or to infrastructure controlled by Wonderlog.

When configured, that same offline-authorized style becomes
`AppConfig.effectiveMapStyleUrl` for rendering. Therefore the resources
downloaded into the native MapLibre offline store are the same style/resources
the Journey map asks MapLibre to render.

There is intentionally no fallback that bulk-downloads the standard
OpenStreetMap raster service.

### Region lifecycle

Per Journey the app can:
- derive a bounded region from geotagged Journey content;
- use a 2–50 km radius envelope;
- download zoom levels 8–15;
- expose native download progress;
- persist metadata/progress in Drift;
- verify the actual native MapLibre region before claiming it is downloaded;
- repair stale Drift state when the native region was evicted or removed;
- delete the native region and local metadata.

MapLibre native offline is available on Android/iOS. Web remains online-only and
the UI says so instead of simulating an offline download.

## Premium boundary

Offline Maps remains a Premium-only capability:
- Free: blocked by `PremiumAccessPolicy`;
- Premium: allowed by the product capability gate;
- runtime still checks platform and provider configuration.

The paywall does not blindly advertise offline maps for a build without an
authorized offline provider.

## Locale-aware Nominatim

`OpenStreetMapRepository` now receives the effective app locale from
`AppController`.

Locale source:
- manual Wonderlog language when selected;
- otherwise current device locale.

Search and reverse-geocoding now:
- send the locale as `accept-language`;
- send the same value in `Accept-Language`;
- use an app-specific User-Agent;
- serialize Nominatim network starts to at most one request per second;
- retain local cache-first behavior.

Cache keys are versioned and locale-scoped:

`v2|search|<locale>|<query>`

`v2|reverse|<locale>|<lat,lon>`

Therefore an Italian result cannot satisfy a later English lookup for the same
query/coordinate.

Wonderlog currently has no production type-ahead Nominatim autocomplete caller.
Step 26 does not introduce one.

## Deterministic coverage

Added/updated tests cover:
- replay-path near-duplicate collapsing;
- no routing network call when routing is unconfigured;
- OSRM-compatible GeoJSON road-route parsing;
- app locale in Nominatim query/header;
- locale-specific geocoding cache isolation;
- locale-specific reverse-geocode cache isolation;
- effective MapLibre style selection when an offline-authorized style exists;
- Premium/Free Offline Maps gating.

## External-provider truth

Step 26 completes the application/runtime architecture but does not invent a
production offline tile entitlement.

A production release that wants downloadable offline maps must still supply:
- an authorized/self-controlled MapLibre style endpoint through
  `WONDERLOG_OFFLINE_MAP_STYLE_URL`;
- any provider credentials through release-safe configuration if needed;
- a real-device download/offline/relaunch/delete drill before claiming physical
  certification.

Likewise, real road routing needs a configured OSRM-compatible endpoint through
`WONDERLOG_ROUTING_URL`.

## Evidence boundary

Deterministic Flutter CI can certify:
- static correctness;
- unit behavior;
- Web release compilation;
- Android APK/AAB compilation.

It cannot by itself prove a real provider's tile entitlement, network behavior,
native offline persistence, or physical airplane-mode behavior.

Accordingly:
- replay/geocoding/routing contracts can reach deterministic FULL evidence;
- native offline engine is implemented and CI-buildable;
- final physical offline-provider certification remains a release/configuration
  gate, not something to fake inside Step 26.

The next structural block after this implementation is
**MAXI STEP 27 — Release Hardening**.
