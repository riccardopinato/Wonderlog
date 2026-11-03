import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/gpx_preview_service.dart';

/// Read-only GPX summary: never commits data to a Journey or to storage.
final class GpxPreviewPage extends StatefulWidget {
  const GpxPreviewPage({super.key});

  @override
  State<GpxPreviewPage> createState() => _GpxPreviewPageState();
}

final class _GpxPreviewPageState extends State<GpxPreviewPage> {
  bool _busy=false;
  bool _error=false;
  String? _fileName;
  GpxPreviewData? _preview;

  Future<void> _pick() async {
    setState(() {
      _busy=true;
      _error=false;
      _fileName=null;
      _preview=null;
    });
    try {
      final selected=await FilePicker.platform.pickFiles(
        type:FileType.custom,
        allowedExtensions:const ['gpx'],
        allowMultiple:false,
        withData:true,
      );
      if (!mounted) return;
      if (selected==null || selected.files.isEmpty) {
        setState(()=>_busy=false);
        return;
      }
      final file=selected.files.single;
      const maxBytes=5*1024*1024;
      if(file.size>maxBytes || file.bytes==null ||
         file.bytes!.length>maxBytes) {
        throw const FormatException('GPX byte limit or missing input');
      }
      final xml=utf8.decode(file.bytes!,allowMalformed:false);
      // Isolate on mobile, supported fallback on Flutter Web.
      final result=await compute(GpxPreviewService.parse,xml);
      if(!mounted)return;
      setState(() {
        _fileName=file.name;
        _preview=result;
        _busy=false;
      });
    } catch (_) {
      if(!mounted)return;
      setState(() {
        _preview=null;
        _busy=false;
        _error=true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings=AppLocalizations.of(context);
    final preview=_preview;
    return Scaffold(
      appBar:AppBar(title:Text(strings.gpxPreviewTitle)),
      body:ListView(
        padding:const EdgeInsets.all(WonderlogSpacing.medium),
        children:[
          Text(strings.gpxPreviewNote),
          const SizedBox(height:WonderlogSpacing.medium),
          FilledButton.icon(
            onPressed:_busy ? null : _pick,
            icon:const Icon(Icons.file_open_outlined),
            label:Text(strings.gpxPreviewChoose),
          ),
          if(_busy) const Padding(
            padding:EdgeInsets.only(top:16),
            child:LinearProgressIndicator(),
          ),
          if(_error) Padding(
            padding:const EdgeInsets.only(top:16),
            child:Text(strings.gpxPreviewInvalid,
              style:TextStyle(color:Theme.of(context).colorScheme.error)),
          ),
          if(preview!=null) ...[
            const SizedBox(height:WonderlogSpacing.medium),
            if(_fileName!=null)
              Text(_fileName!,style:Theme.of(context).textTheme.titleMedium),
            Card(child:Column(children:[
              ListTile(
                leading:const Icon(Icons.route_outlined),
                title:Text(strings.gpxPreviewTotal),
                trailing:Text(preview.totalPoints.toString()),
              ),
              ListTile(
                leading:const Icon(Icons.place_outlined),
                title:Text(strings.gpxPreviewWaypoints),
                trailing:Text(preview.waypointCount.toString()),
              ),
            ])),
            for(final section in preview.tracks)
              Card(child:ListTile(
                leading:const Icon(Icons.timeline_outlined),
                title:Text(section.name?.isNotEmpty==true
                  ? section.name!
                  : strings.gpxPreviewTrack+' '+section.index.toString()),
                subtitle:Text(strings.gpxPreviewSegments+' '+
                  section.segmentCount.toString()),
                trailing:Text(section.pointCount.toString()+' '+
                  strings.gpxPreviewPoints),
              )),
            for(final section in preview.routes)
              Card(child:ListTile(
                leading:const Icon(Icons.alt_route_outlined),
                title:Text(section.name?.isNotEmpty==true
                  ? section.name!
                  : strings.gpxPreviewRoute+' '+section.index.toString()),
                trailing:Text(section.pointCount.toString()+' '+
                  strings.gpxPreviewPoints),
              )),
          ],
        ],
      ),
    );
  }
}
