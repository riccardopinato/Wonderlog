import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/ecosystem_transfer_service.dart';
import '../../../core/ecosystem/wonderlog_ecosystem_adapter.dart';
import '../../../core/picker/device_content_picker.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../premium/domain/premium_gate.dart';
import '../../premium/presentation/premium_page.dart';
import '../application/keepsake_file_actions.dart';
import '../data/photo_import_service.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';
import 'memory_editor_page.dart';
import 'photo_viewer_page.dart';
import 'stored_media_image.dart';

final class MemoryDetailPage extends StatefulWidget {
  const MemoryDetailPage({
    super.key,
    required this.repository,
    required this.memoryId,
  });

  final WonderlogRepository repository;
  final String memoryId;

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

final class _MemoryDetailPageState extends State<MemoryDetailPage> {
  final DeviceContentPicker _picker = const DeviceContentPicker();
  final KeepsakeFileActions _fileActions = const KeepsakeFileActions();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return StreamBuilder<MemoryWithPhotos?>(
      stream: widget.repository.watchMemory(widget.memoryId),
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(strings.memoryUnavailable)),
          );
        }

        final memory = item.memory;
        final locale = Localizations.localeOf(context).toLanguageTag();

        return Scaffold(
          appBar: AppBar(
            title: Text(strings.memoryDetail),
            actions: [
              PopupMenuButton<EcosystemTransferMode>(
                tooltip: strings.lifeBridgeShareToAnna,
                enabled: !_busy,
                icon: const Icon(Icons.hub_outlined),
                onSelected: (mode) => _shareToAnna(
                  context,
                  item,
                  mode,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: EcosystemTransferMode.copy,
                    child: Text(strings.lifeBridgeCopyToAnna),
                  ),
                  PopupMenuItem(
                    value: EcosystemTransferMode.link,
                    child: Text(strings.lifeBridgeLinkToAnna),
                  ),
                ],
              ),
              IconButton(
                tooltip: strings.memoryEdit,
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MemoryEditorPage(
                              repository: widget.repository,
                              journeyId: memory.journeyId,
                              existing: memory,
                            ),
                          ),
                        ),
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (action) => _handleMemoryAction(
                  context,
                  item,
                  action,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'move',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.drive_file_move_outline),
                      title: Text(
                        memory.journeyId == null
                            ? strings.memoryAssignJourney
                            : strings.memoryMoveTitle,
                      ),
                    ),
                  ),
                  if (memory.journeyId != null)
                    PopupMenuItem(
                      value: 'unassign',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link_off_outlined),
                        title: Text(strings.memoryMakeUnassigned),
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
                child: ListView(
                  padding: const EdgeInsets.all(WonderlogSpacing.medium),
                  children: [
                    Text(
                      memory.title,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: WonderlogSpacing.small),
                    Wrap(
                      spacing: WonderlogSpacing.small,
                      runSpacing: WonderlogSpacing.xSmall,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            memory.mood.emoji + ' ' + memory.mood.label,
                          ),
                        ),
                        Chip(
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(
                            DateFormat.yMMMd(locale).format(memory.date),
                          ),
                        ),
                        if (memory.locationName.trim().isNotEmpty)
                          Chip(
                            avatar:
                                const Icon(Icons.place_outlined, size: 16),
                            label: Text(memory.locationName),
                          ),
                        if (memory.journeyId == null)
                          Chip(
                            avatar:
                                const Icon(Icons.inbox_outlined, size: 16),
                            label: Text(strings.memoryUnassigned),
                          ),
                      ],
                    ),
                    if (memory.journalText.trim().isNotEmpty) ...[
                      const SizedBox(height: WonderlogSpacing.large),
                      Text(
                        strings.memoryJournal,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: WonderlogSpacing.small),
                      Text(
                        memory.journalText,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.55,
                                ),
                      ),
                    ],
                    if (memory.tags.isNotEmpty) ...[
                      const SizedBox(height: WonderlogSpacing.large),
                      Wrap(
                        spacing: WonderlogSpacing.xSmall,
                        runSpacing: WonderlogSpacing.xSmall,
                        children: memory.tags
                            .map((tag) => Chip(label: Text('#$tag')))
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: WonderlogSpacing.large),
                    Text(
                      strings.memoryPhotos,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: WonderlogSpacing.small),
                    if (item.photos.isEmpty)
                      Text(strings.memoryNoPhotos)
                    else
                      SizedBox(
                        height: 132,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.photos.length,
                          separatorBuilder: (_, _) => const SizedBox(
                            width: WonderlogSpacing.small,
                          ),
                          itemBuilder: (context, index) {
                            final photo = item.photos[index];
                            return SizedBox(
                              width: 160,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => PhotoViewerPage(
                                        repository: widget.repository,
                                        photo: photo,
                                        memoryId: memory.id,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      StoredMediaImage(
                                        references: [
                                          photo.thumbnailUri,
                                          photo.localUri,
                                          photo.originalUri,
                                        ],
                                      ),
                                      Positioned(
                                        left: 6,
                                        right: 6,
                                        bottom: 6,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withValues(alpha: 0.84),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(5),
                                            child: Text(
                                              photo.fileName.isEmpty
                                                  ? strings.photo
                                                  : photo.fileName,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: WonderlogSpacing.large),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.memoryKeepsakes,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              _busy ? null : () => _importKeepsakes(item),
                          icon:
                              const Icon(Icons.attach_file_outlined),
                          label: Text(strings.keepsakeAdd),
                        ),
                      ],
                    ),
                    const SizedBox(height: WonderlogSpacing.small),
                    if (item.attachments.isEmpty)
                      Text(strings.memoryNoKeepsakes)
                    else
                      ...item.attachments.map(
                        (attachment) => _KeepsakeCard(
                          attachment: attachment,
                          onOpen: () => _openKeepsake(attachment),
                          onShare: () => _shareKeepsake(attachment),
                          onExport: () => _exportKeepsake(attachment),
                          onRename: () => _renameKeepsake(attachment),
                          onDelete: () => _deleteKeepsake(attachment),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleMemoryAction(
    BuildContext context,
    MemoryWithPhotos item,
    String action,
  ) async {
    final strings = AppLocalizations.of(context);
    switch (action) {
      case 'move':
        await _moveMemory(item.memory);
        break;
      case 'unassign':
        if (!await _ensureMemoryDestinationAvailable(null)) return;
        await _run(
          () => widget.repository.moveMemoryToJourney(
            item.memory.id,
            null,
          ),
        );
        if (mounted) {
          _message(strings.memoryMoved);
        }
        break;
      case 'delete':
        await _deleteMemory(item);
        break;
    }
  }

  Future<void> _moveMemory(MemoryEntry memory) async {
    final strings = AppLocalizations.of(context);
    final journeys = await widget.repository.watchJourneys().first;
    if (!mounted) return;
    if (journeys.isEmpty) {
      _message(strings.ecosystemNoJourneys);
      return;
    }

    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(strings.memoryMoveTitle),
        children: [
          for (final journey in journeys)
            if (journey.id != memory.journeyId)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(dialogContext, journey.id),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.luggage_outlined),
                  title: Text(journey.title),
                  subtitle: Text(journey.destination),
                ),
              ),
        ],
      ),
    );
    if (destination == null || !mounted) return;
    if (!await _ensureMemoryDestinationAvailable(destination)) return;
    await _run(
      () => widget.repository.moveMemoryToJourney(
        memory.id,
        destination,
      ),
    );
    if (mounted) _message(strings.memoryMoved);
  }

  Future<bool> _ensureMemoryDestinationAvailable(
    String? journeyId,
  ) async {
    final services = WonderlogServicesScope.of(context);
    final access = await services.premiumAccessPolicy.canCreateMemory(
      journeyId: journeyId,
    );
    if (!mounted) return false;
    if (access is PremiumLimitReached) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PremiumPage(
            service: services.controller.premiumService,
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _deleteMemory(MemoryWithPhotos item) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.memoryDeleteTitle),
        content: Text(strings.memoryDeleteDescription),
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

    final removedReferences =
        item.attachments.map((attachment) => attachment.localUri).toSet();
    await _run(() async {
      final services = WonderlogServicesScope.of(context);
      await widget.repository.deleteMemory(item.memory.id);
      final remaining = await widget.repository.referencedMediaUris();
      for (final reference in removedReferences) {
        await services.photoImportService.deleteStoredReferenceIfUnreferenced(
          reference,
          remainingReferences: remaining,
        );
      }
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _importKeepsakes(MemoryWithPhotos item) async {
    final incoming = await _picker.pickKeepsakes();
    if (incoming.isEmpty || !mounted) return;

    await _run(() async {
      final services = WonderlogServicesScope.of(context);
      final existing = <MemoryAttachment>[...item.attachments];
      var failed = false;
      for (final source in incoming) {
        final uri = source.uri?.trim();
        if (uri == null || uri.isEmpty) continue;
        try {
          final attachment =
              await services.photoImportService.importKeepsake(
            memoryId: item.memory.id,
            sourceUri: uri,
            existingAttachments: existing,
            fileName: source.title,
            mimeType: source.mimeType,
          );
          await widget.repository.saveAttachment(attachment);
          existing.add(attachment);
        } on PhotoImportException {
          failed = true;
        }
      }
      if (failed && mounted) {
        _message(AppLocalizations.of(context).keepsakeImportFailed);
      }
    });
  }

  Future<List<int>?> _attachmentBytes(
    MemoryAttachment attachment,
  ) =>
      WonderlogServicesScope.of(context)
          .photoImportService
          .readReference(attachment.localUri);

  Future<void> _openKeepsake(MemoryAttachment attachment) =>
      _withAttachmentBytes(
        attachment,
        (bytes, name) => _fileActions.open(
          bytes: bytes,
          fileName: name,
          mimeType: attachment.mimeType,
        ),
      );

  Future<void> _shareKeepsake(MemoryAttachment attachment) =>
      _withAttachmentBytes(
        attachment,
        (bytes, name) => _fileActions.share(
          bytes: bytes,
          fileName: name,
          mimeType: attachment.mimeType,
        ),
      );

  Future<void> _exportKeepsake(MemoryAttachment attachment) =>
      _withAttachmentBytes(
        attachment,
        (bytes, name) async {
          final result = await _fileActions.export(
            bytes: bytes,
            fileName: name,
          );
          if (result != null && mounted) {
            _message(AppLocalizations.of(context).keepsakeExported);
          }
        },
      );

  Future<void> _withAttachmentBytes(
    MemoryAttachment attachment,
    Future<void> Function(List<int> bytes, String name) action,
  ) async {
    await _run(() async {
      final bytes = await _attachmentBytes(attachment);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          _message(AppLocalizations.of(context).keepsakeUnavailable);
        }
        return;
      }
      try {
        await action(
          bytes,
          attachment.originalName?.trim().isNotEmpty == true
              ? attachment.originalName!.trim()
              : 'keepsake.bin',
        );
      } catch (_) {
        if (mounted) {
          _message(AppLocalizations.of(context).keepsakeActionFailed);
        }
      }
    });
  }

  Future<void> _renameKeepsake(MemoryAttachment attachment) async {
    final strings = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: attachment.originalName ?? '',
    );
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.keepsakeRename),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext, name);
              },
              child: Text(strings.save),
            ),
          ],
        ),
      );
      if (value == null || !mounted) return;
      await _run(
        () => widget.repository.saveAttachment(
          MemoryAttachment(
            id: attachment.id,
            memoryId: attachment.memoryId,
            localUri: attachment.localUri,
            originalName: value,
            mimeType: attachment.mimeType,
            attachmentType: attachment.attachmentType,
            createdAt: attachment.createdAt,
            syncStatus: attachment.syncStatus,
          ),
        ),
      );
      if (mounted) _message(strings.keepsakeRenamed);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteKeepsake(MemoryAttachment attachment) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.keepsakeDeleteTitle),
        content: Text(strings.keepsakeDeleteDescription),
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
      await widget.repository.deleteAttachment(attachment.id);
      final remaining = await widget.repository.referencedMediaUris();
      await services.photoImportService.deleteStoredReferenceIfUnreferenced(
        attachment.localUri,
        remainingReferences: remaining,
      );
    });
  }

  Future<void> _shareToAnna(
    BuildContext context,
    MemoryWithPhotos item,
    EcosystemTransferMode mode,
  ) async {
    final services = WonderlogServicesScope.of(context);
    final result = await services.ecosystemTransferService.send(
      targetApp: EcosystemAppId.annasDiary,
      envelope: WonderlogEcosystemAdapter.memory(
        item.memory,
        photos: item.photos,
        mode: mode,
      ),
    );
    if (!context.mounted) return;
    final strings = AppLocalizations.of(context);
    final message = switch (result.status) {
      EcosystemDeliveryStatus.openedTarget => strings.ecosystemOpenedAnna,
      EcosystemDeliveryStatus.fallbackCopied =>
        strings.lifeBridgeCopiedForAnna,
      EcosystemDeliveryStatus.unsupported =>
        strings.ecosystemUnsupportedAnna,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

final class _KeepsakeCard extends StatelessWidget {
  const _KeepsakeCard({
    required this.attachment,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
    required this.onRename,
    required this.onDelete,
  });

  final MemoryAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onExport;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final isImage = attachment.mimeType.toLowerCase().startsWith('image/');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (isImage)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: StoredMediaImage(
                references: [attachment.localUri],
                width: double.infinity,
                height: 140,
              ),
            ),
          ListTile(
            leading: Icon(
              isImage
                  ? Icons.image_outlined
                  : Icons.description_outlined,
            ),
            title: Text(
              attachment.originalName ??
                  strings.memoryKeepsakeDocument,
            ),
            subtitle: Text(attachment.mimeType),
            onTap: onOpen,
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'open':
                    onOpen();
                    break;
                  case 'share':
                    onShare();
                    break;
                  case 'export':
                    onExport();
                    break;
                  case 'rename':
                    onRename();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'open',
                  child: Text(strings.keepsakeOpen),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text(strings.keepsakeShare),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Text(strings.keepsakeExport),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Text(strings.keepsakeRename),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(strings.delete),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
