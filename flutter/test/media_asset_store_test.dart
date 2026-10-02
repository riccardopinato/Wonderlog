import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/media/content_addressed_media_asset_store.dart';
import 'package:wonderlog/core/media/memory_media_asset_backend.dart';

void main() {
  test('original assets are content addressed and deduplicated', () async {
    final backend = MemoryMediaAssetBackend();
    final store = ContentAddressedMediaAssetStore(backend);

    final first = await store.putOriginal([1, 2, 3]);
    final second = await store.putOriginal([1, 2, 3]);

    expect(first, second);
    expect(await store.listStoredAssetIds(), {first});
    expect(await store.read(first), [1, 2, 3]);
  });

  test('corrupt content-addressed assets fail closed', () async {
    final backend = MemoryMediaAssetBackend();
    final store = ContentAddressedMediaAssetStore(backend);
    final id = contentAssetId([1, 2, 3]);
    await backend.write(id, [9, 9, 9]);

    expect(await store.read(id), isNull);
  });

  test('prune removes only unreferenced assets', () async {
    final backend = MemoryMediaAssetBackend();
    final store = ContentAddressedMediaAssetStore(backend);
    final keep = await store.putOriginal([1]);
    await store.putOriginal([2]);

    expect(await store.prune({keep}), 1);
    expect(await store.listStoredAssetIds(), {keep});
  });
}
