import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/runtime/wonderlog_services_scope.dart';

final class StoredMediaImage extends StatefulWidget {
  const StoredMediaImage({
    super.key,
    required this.references,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  final List<String> references;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<StoredMediaImage> createState() => _StoredMediaImageState();
}

final class _StoredMediaImageState extends State<StoredMediaImage> {
  Future<Uint8List?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant StoredMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameReferences(oldWidget.references, widget.references)) {
      _refresh();
    }
  }

  void _refresh() {
    final service = WonderlogServicesScope.of(context).photoImportService;
    _future = () async {
      for (final reference in widget.references) {
        final normalized = reference.trim();
        if (normalized.isEmpty) continue;
        final bytes = await service.readReference(normalized);
        if (bytes != null && bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      }
      return null;
    }();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          Widget child;
          if (snapshot.connectionState == ConnectionState.waiting) {
            child = const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          } else if (bytes == null) {
            child = Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          } else {
            child = Image.memory(
              bytes,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined),
              ),
            );
          }

          final radius = widget.borderRadius;
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: radius == null
                ? child
                : ClipRRect(borderRadius: radius, child: child),
          );
        },
      );

  bool _sameReferences(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
