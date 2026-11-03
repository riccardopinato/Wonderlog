/// Local-only, read-only GPX preview for travel journal import planning.
/// No route snapping, image geotag reassignment, or persisted user writes.
library;
import 'gpx_reference.dart';

final class GpxPreviewSection {
  const GpxPreviewSection({required this.index,required this.pointCount,
      required this.segmentCount,this.name});
  final int index,pointCount,segmentCount;
  final String? name;
}

final class GpxPreviewData {
  const GpxPreviewData({required this.tracks,required this.routes,
      required this.waypointCount,required this.totalPoints});
  final List<GpxPreviewSection> tracks,routes;
  final int waypointCount,totalPoints;
}

abstract final class GpxPreviewService {
  static GpxPreviewData parse(String xml) {
    final result=GpxReferenceEngine.parse(xml);
    final doc=result.document;
    return GpxPreviewData(
      tracks:List.unmodifiable([
        for(var i=0;i<doc.tracks.length;i++)
          GpxPreviewSection(index:i+1,name:doc.tracks[i].name,
            pointCount:doc.tracks[i].segments.fold<int>(
              0,(sum,s)=>sum+s.length),
            segmentCount:doc.tracks[i].segments.length),
      ]),
      routes:List.unmodifiable([
        for(var i=0;i<doc.routes.length;i++)
          GpxPreviewSection(index:i+1,name:doc.routes[i].name,
            pointCount:doc.routes[i].points.length,segmentCount:1),
      ]),
      waypointCount:doc.waypoints.length,totalPoints:result.originalPointCount,
    );
  }
}
