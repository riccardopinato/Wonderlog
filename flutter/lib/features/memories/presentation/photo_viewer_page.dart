import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';
import 'stored_media_image.dart';

final class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.repository,
    required this.photo,
    this.memoryId,
  });

  final WonderlogRepository repository;
  final AlbumPhotoEntry photo;
  final String? memoryId;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

final class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late AlbumPhotoEntry _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _photo.fileName.trim().isEmpty ? strings.photo : _photo.fileName,
        ),
        actions: [
          IconButton(
            tooltip: _photo.favorite
                ? strings.photoRemoveFavorite
                : strings.photoAddFavorite,
            onPressed: _busy ? null : _toggleFavorite,
            icon: Icon(
              _photo.favorite ? Icons.favorite : Icons.favorite_border,
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: _handleMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'cover',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wallpaper_outlined),
                  title: Text(
                    _photo.isCoverPhoto
                        ? strings.photoClearCover
                        : strings.photoSetCover,
                  ),
                ),
              ),
              if (widget.memoryId != null)
                PopupMenuItem(
                  value: 'unlink',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_off_outlined),
                    title: Text(strings.photoUnlinkMemory),
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline),
                  title: Text(strings.delete),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: StoredMediaImage(
                  references: [
                    _photo.localUri,
                    _photo.thumbnailUri,
                    _photo.originalUri,
                  ],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            child: Wrap(
              spacing: WonderlogSpacing.small,
              runSpacing: WonderlogSpacing.xSmall,
              children: [
                if (_photo.locationName.trim().isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.place_outlined, size: 16),
                    label: Text(_photo.locationName),
                  ),
                if (_photo.fileSize > 0)
                  Chip(
                    avatar: const Icon(Icons.storage_outlined, size: 16),
                    label: Text(_formatBytes(_photo.fileSize)),
                  ),
                if (_photo.isCoverPhoto)
                  Chip(
                    avatar: const Icon(Icons.wallpaper_outlined, size: 16),
                    label: Text(strings.photoCover),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(String action) async {
    switch (action) {
      case 'cover':
        await _setCover();
        break;
      case 'unlink':
        await _unlink();
        break;
      case 'delete':
        await _delete();
        break;
    }
  }

  Future<void> _toggleFavorite() async {
    await _run(() async {
      final updated = _copyPhoto(favorite: !_photo.favorite);
      await widget.repository.savePhoto(updated);
      if (mounted) setState(() => _photo = updated);
    });
  }

  Future<void> _setCover() async {
    await _run(() async {
      await widget.repository.setJourneyCoverPhoto(
        journeyId: _photo.journeyId,
        photoId: _photo.isCoverPhoto ? null : _photo.id,
      );
      if (mounted) {
        setState(
          () => _photo = _copyPhoto(isCoverPhoto: !_photo.isCoverPhoto),
        );
      }
    });
  }

  Future<void> _unlink() async {
    final memoryId = widget.memoryId;
    if (memoryId == null) return;
    await _run(() async {
      await widget.repository.unlinkPhotoFromMemory(
        memoryId: memoryId,
        photoId: _photo.id,
      );
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _delete() async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.photoDeleteTitle),
        content: Text(strings.photoDeleteDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(() async {
      final services = WonderlogServicesScope.of(context);
      final reference = _photo.localUri;
      await widget.repository.deletePhoto(_photo.id);
      final remaining = await widget.repository.referencedMediaUris();
      await services.photoImportService.deleteStoredReferenceIfUnreferenced(
        reference,
        remainingReferences: remaining,
      );
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AlbumPhotoEntry _copyPhoto({
    bool? favorite,
    bool? isCoverPhoto,
  }) =>
      AlbumPhotoEntry(
        id: _photo.id,
        journeyId: _photo.journeyId,
        localUri: _photo.localUri,
        thumbnailUri: _photo.thumbnailUri,
        originalUri: _photo.originalUri,
        fileName: _photo.fileName,
        mimeType: _photo.mimeType,
        width: _photo.width,
        height: _photo.height,
        fileSize: _photo.fileSize,
        createdAt: _photo.createdAt,
        updatedAt: DateTime.now().toUtc(),
        capturedAt: _photo.capturedAt,
        gpsLatitude: _photo.gpsLatitude,
        gpsLongitude: _photo.gpsLongitude,
        locationName: _photo.locationName,
        favorite: favorite ?? _photo.favorite,
        isCoverPhoto: isCoverPhoto ?? _photo.isCoverPhoto,
        displayOrder: _photo.displayOrder,
        syncStatus: _photo.syncStatus,
        futureCloudId: _photo.futureCloudId,
      );

  String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(0)} KB';
    }
    return '$value B';
  }
}
