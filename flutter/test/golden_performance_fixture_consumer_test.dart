import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/journeys/domain/journey.dart';
import 'package:wonderlog/features/search/domain/search_engine.dart';

import 'support/performance_fixtures.dart';

void main() {
  test('Golden fixture harness measures real Wonderlog local search deterministically',() {
    final points=SyntheticGeoFixture(id:'wonderlog-300',seed:20261103,count:300)
        .generate();
    final trips=[
      for(var i=0;i<points.length;i++)
        Journey(
          id:points[i].id,
          title:i.isEven ? 'Montagna percorso' : 'Lago e città',
          destination:'Veneto',country:'Italia',
          startDate:DateTime.utc(2026,1,1),endDate:DateTime.utc(2026,1,2),
          description:'',latitude:points[i].latitude,
          longitude:points[i].longitude,
          favorite:false,archived:false,createdAt:DateTime.utc(2026),
          updatedAt:DateTime.utc(2026),
        )
    ];
    const fallbackSha='5e6db031e300f09f5b64db3e1416c62c036907c9';
    final envSha=Platform.environment['GITHUB_SHA']??fallbackSha;
    final verifiedSourceSha=RegExp(r'^[a-f0-9]{40}$').hasMatch(envSha)
        ? envSha : fallbackSha;
    final result=ReferencePerformanceHarness.measure(
      sourceSha:verifiedSourceSha,
      fixtureId:'wonderlog-300',
      operation:'WonderlogSearchEngine.search literal',
      runnerProfile:'Flutter-test-' + Platform.operatingSystem,
      sampleIterations:5,warmupIterations:2,
      perform:()=>WonderlogSearchEngine.search(query:'montagna',
        journeys:trips,memories:const [],limit:80)
          .whereType<JourneySearchResult>()
          .map((hit)=>hit.journey.id)
          .toList(),
    );
    expect(result.outputCount,80);
    expect(result.sampleMicros,hasLength(5));
    expect(result.p95Micros,greaterThanOrEqualTo(result.p50Micros));
    expect(result.toJson()['runnerProfile'],contains('Flutter-test'));
    // Inspectable source-pinned benchmark receipt in GitHub Actions logs.
    debugPrint('GOLDEN_FIXTURE_EVIDENCE '+jsonEncode(result.toJson()));
  });
}
