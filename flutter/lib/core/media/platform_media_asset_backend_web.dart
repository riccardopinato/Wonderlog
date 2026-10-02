import 'media_asset_backend.dart';
import 'memory_media_asset_backend.dart';

Future<MediaAssetBackend> createPlatformMediaAssetBackend() async =>
    MemoryMediaAssetBackend();
