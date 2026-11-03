/// Deterministic synthetic workload generator and reproducible benchmark
/// evidence. Timing numbers are runner-specific and never device certification.
library;

import 'spatial_clustering.dart';

final class FixtureReferenceException implements Exception {
  const FixtureReferenceException(this.code);
  final String code;
}

enum FixtureDistribution { uniform, sameLocation, antimeridian }

final class SyntheticGeoFixture {
  SyntheticGeoFixture({
    required this.id,
    required this.seed,
    required this.count,
    this.distribution = FixtureDistribution.uniform,
  }) {
    if (id.trim().isEmpty || seed < 0 || count < 0 || count > 10000) {
      throw const FixtureReferenceException('INVALID_FIXTURE');
    }
  }
  final String id;
  final int seed;
  final int count;
  final FixtureDistribution distribution;
  static const generatorVersion = 1;

  List<SpatialPoint> generate() {
    var state = seed & 0x7fffffff;
    double nextFraction() {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state / 2147483647.0;
    }
    return List<SpatialPoint>.unmodifiable(List.generate(count,(i) {
      final latitude= -85.0 + 170.0*nextFraction();
      final longitude= -180.0 + 360.0*nextFraction();
      return switch (distribution) {
        FixtureDistribution.uniform => SpatialPoint('geo-$i',latitude,longitude),
        FixtureDistribution.sameLocation => SpatialPoint('geo-$i',45,10),
        FixtureDistribution.antimeridian => SpatialPoint('geo-$i',
            44.999 + i%10*0.0001, i.isEven ? 179.999 : -179.999),
      };
    }));
  }
}

final class ReferenceBenchmarkResult {
  const ReferenceBenchmarkResult({
    required this.sourceSha,
    required this.fixtureId,
    required this.runnerProfile,
    required this.operation,
    required this.warmupIterations,
    required this.sampleMicros,
    required this.outputCount,
    required this.integrityDigest,
  });
  final String sourceSha, fixtureId, runnerProfile, operation;
  final int warmupIterations, outputCount, integrityDigest;
  final List<int> sampleMicros;
  int get p50Micros => _percentile(0.50);
  int get p95Micros => _percentile(0.95);
  int _percentile(double rank) {
    final sorted=[...sampleMicros]..sort();
    return sorted[((sorted.length - 1)*rank).ceil()];
  }
  Map<String,Object> toJson() => {
    'sourceSha':sourceSha, 'fixtureId':fixtureId,
    'runnerProfile':runnerProfile, 'operation':operation,
    'warmupIterations':warmupIterations, 'outputCount':outputCount,
    'integrityDigest':integrityDigest, 'sampleMicros':sampleMicros,
    'p50Micros':p50Micros, 'p95Micros':p95Micros,
  };
}

abstract final class ReferencePerformanceHarness {
  static ReferenceBenchmarkResult measure({
    required String sourceSha,
    required String fixtureId,
    required String operation,
    required String runnerProfile,
    required List<String> Function() perform,
    int warmupIterations = 1,
    int sampleIterations = 5,
  }) {
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceSha) ||
        fixtureId.isEmpty || operation.isEmpty || runnerProfile.isEmpty ||
        warmupIterations < 1 || warmupIterations > 20 ||
        sampleIterations < 3 || sampleIterations > 30) {
      throw const FixtureReferenceException('INVALID_MEASUREMENT');
    }
    int? expectedDigest;
    int? expectedCount;
    void verify(List<String> output) {
      final digest=_fnv1a(output);
      if (expectedDigest == null) {
        expectedDigest=digest;
        expectedCount=output.length;
      } else if (digest != expectedDigest || output.length != expectedCount) {
        throw const FixtureReferenceException('INCONSISTENT_OUTPUT');
      }
    }
    for(var i=0;i<warmupIterations;i++) { verify(perform()); }
    final times=<int>[];
    for(var i=0;i<sampleIterations;i++) {
      final watch=Stopwatch()..start();
      final output=perform();
      watch.stop();
      verify(output);
      times.add(watch.elapsedMicroseconds);
    }
    return ReferenceBenchmarkResult(
      sourceSha:sourceSha, fixtureId:fixtureId,operation:operation,
      runnerProfile:runnerProfile,warmupIterations:warmupIterations,
      sampleMicros:List.unmodifiable(times),outputCount:expectedCount!,
      integrityDigest:expectedDigest!,
    );
  }

  static int _fnv1a(List<String> values) {
    var hash=0x811c9dc5;
    for (final item in values) {
      for (final unit in item.codeUnits) {
        hash ^= unit;
        hash = (hash*0x01000193) & 0xffffffff;
      }
      hash ^= 0xff;
      hash = (hash*0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
