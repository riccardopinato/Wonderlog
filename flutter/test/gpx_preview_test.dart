import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/gpx/domain/gpx_preview_service.dart';
import 'package:wonderlog/features/gpx/domain/gpx_reference.dart';

void main() {
  test('real preview adapter reads tracks, routes, waypoints and segment bounds',() {
    const xml='''<?xml version="1.0"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1">
<trk><name>Alpi</name><trkseg><trkpt lat="45" lon="10"/></trkseg>
<trkseg><trkpt lat="45.1" lon="10.1"/></trkseg></trk>
<rte><name>Retour</name><rtept lat="45.2" lon="10.2"/></rte>
<wpt lat="45.3" lon="10.3"><name>Stop</name></wpt>
</gpx>''';
    final preview=GpxPreviewService.parse(xml);
    expect(preview.totalPoints,4);
    expect(preview.tracks.single.name,'Alpi');
    expect(preview.tracks.single.segmentCount,2);
    expect(preview.tracks.single.pointCount,2);
    expect(preview.routes.single.name,'Retour');
    expect(preview.routes.single.pointCount,1);
    expect(preview.waypointCount,1);
  });

  test('independent GPX consumer rejects invalid and external entity inputs',() {
    expect(()=>GpxPreviewService.parse('<gpx><wpt lat="91" lon="0"/></gpx>'),
      throwsA(isA<GpxFormatException>().having(
        (e)=>e.code,'code','INVALID_COORDINATE')));
    expect(()=>GpxPreviewService.parse('<!DOCTYPE gpx [<!ENTITY x SYSTEM "file:///private">]><gpx>&x;</gpx>'),
      throwsA(isA<GpxFormatException>().having(
        (e)=>e.code,'code','UNSAFE_XML')));
    expect(()=>GpxPreviewService.parse('<gpx/>'),
      throwsA(isA<GpxFormatException>().having(
        (e)=>e.code,'code','EMPTY_GPX')));
  });

  test('roundtrip of exported route is accepted by independent adapter',() {
    final original=GpxDocument(routes:[
      GpxRoute([GpxPoint(45,10,name:'First'),
                GpxPoint(45.5,10.5,timeUtc:DateTime.utc(2026,11,3))],
               name:'Weekend'),
    ]);
    final serialized=GpxReferenceEngine.export(original);
    final preview=GpxPreviewService.parse(serialized);
    expect(preview.totalPoints,2);
    expect(preview.routes.single.name,'Weekend');
  });
}
