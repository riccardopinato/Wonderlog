import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/export/platform_file_exporter.dart';
import '../../../l10n/app_localizations.dart';
import '../application/journey_pdf_export_service.dart';
import '../domain/pdf_export_models.dart';

final class JourneyPdfExportPage extends StatefulWidget {
  const JourneyPdfExportPage({
    super.key,
    required this.service,
    required this.journeyId,
  });

  final JourneyPdfExportService service;
  final String journeyId;

  @override
  State<JourneyPdfExportPage> createState() => _JourneyPdfExportPageState();
}

final class _JourneyPdfExportPageState extends State<JourneyPdfExportPage> {
  PdfTravelBookStyle _style = PdfTravelBookStyle.editorial;
  bool _includeDescription = true;
  bool _includeAlbum = true;
  bool _includeMemories = true;
  bool _includeLocations = true;
  bool _includeDates = true;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.pdfTravelBookTitle)),
      body: ListView(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        children: [
          Text(
            strings.pdfTravelBookDescription,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: WonderlogSpacing.large),
          SegmentedButton<PdfTravelBookStyle>(
            segments: [
              ButtonSegment(
                value: PdfTravelBookStyle.classic,
                label: Text(strings.pdfStyleClassic),
              ),
              ButtonSegment(
                value: PdfTravelBookStyle.editorial,
                label: Text(strings.pdfStyleEditorial),
              ),
              ButtonSegment(
                value: PdfTravelBookStyle.scrapbook,
                label: Text(strings.pdfStyleScrapbook),
              ),
            ],
            selected: {_style},
            onSelectionChanged: _busy
                ? null
                : (values) => setState(() => _style = values.single),
          ),
          const SizedBox(height: WonderlogSpacing.large),
          SwitchListTile(
            value: _includeDescription,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeDescription = value),
            title: Text(strings.pdfIncludeDescription),
          ),
          SwitchListTile(
            value: _includeMemories,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeMemories = value),
            title: Text(strings.pdfIncludeMemories),
          ),
          SwitchListTile(
            value: _includeAlbum,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeAlbum = value),
            title: Text(strings.pdfIncludeAlbum),
          ),
          SwitchListTile(
            value: _includeLocations,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeLocations = value),
            title: Text(strings.pdfIncludeLocations),
          ),
          SwitchListTile(
            value: _includeDates,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeDates = value),
            title: Text(strings.pdfIncludeDates),
          ),
          if (_error != null) ...[
            const SizedBox(height: WonderlogSpacing.medium),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: WonderlogSpacing.large),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(strings.pdfExport),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final strings = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await widget.service.exportJourney(
        journeyId: widget.journeyId,
        options: PdfExportOptions(
          style: _style,
          includeCover: true,
          includeJourneyDescription: _includeDescription,
          includeAlbumPhotos: _includeAlbum,
          includeMemories: _includeMemories,
          includeLocations: _includeLocations,
          includeDates: _includeDates,
        ),
      );

      final saved = await saveExportedFile(
        fileName: result.fileName,
        bytes: result.bytes,
      );
      if (!mounted || saved == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.pdfExported)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
