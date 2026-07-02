// XFile → PickedAsset mapping shared by the native and web picker
// adapters. XFile is cross-platform (file-backed on native, blob-backed
// on web) so the mapping is lazy on both. INTERNAL — not exported.

import 'package:cross_file/cross_file.dart';

import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/mime_types.dart';

/// Wraps [xFile] lazily — no bytes are read until the consumer asks.
PickedAsset pickedAssetFromXFile(XFile xFile) {
  return PickedAsset.lazy(
    mimeType: xFile.mimeType ?? mimeTypeFromFileName(xFile.name),
    fileName: xFile.name,
    readBytes: xFile.readAsBytes,
    readStream: () => xFile.openRead(),
  );
}
