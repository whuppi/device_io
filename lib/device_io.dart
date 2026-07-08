/// Cross-platform device IO abstraction for Flutter.
///
/// Unified capabilities for image/file picking, sharing, saving to device,
/// and opening files. Same API on iOS, Android, macOS, Windows, Linux,
/// and web.
///
/// ```dart
/// import 'package:device_io/device_io.dart';
///
/// // Construct (sync; adapters resolve per platform):
/// final deviceIO = DeviceIO(
///   config: DeviceIOConfig(downloadsSubfolder: 'MyApp'),
/// );
///
/// // Pick an image:
/// final result = await deviceIO.picker.pickImage();
/// switch (result) {
///   case PlatformSuccess(:final value): use(value);
///   case PlatformCancelled(): break;
///   case PlatformUnsupported(:final reason): hideFeature(reason);
///   case PlatformFailed(:final message): showError(message);
/// }
///
/// // Share a file:
/// await deviceIO.sharer.shareFile(bytes: bytes, fileName: 'photo.png');
///
/// // Save to downloads, then open what was saved:
/// final saved = await deviceIO.saver.save(bytes: bytes, fileName: 'a.csv');
/// if (saved case PlatformSuccess(value: SavedAtPath(:final path))) {
///   await deviceIO.opener.openPath(filePath: path);
/// }
///
/// // Open in the default viewer (all platforms):
/// await deviceIO.opener.openBytes(bytes: bytes, fileName: 'doc.pdf');
/// ```
library;

// ── The coordinator + its config ─────────────────────────────────────
export 'src/runtime/device_io.dart' show DeviceIO;
export 'src/types/device_io_config.dart' show DeviceIOConfig;

// ── Capability contracts ─────────────────────────────────────────────
export 'src/opener/file_opener.dart' show FileOpener;
export 'src/picker/asset_picker.dart' show AssetPicker;
export 'src/picker/image_options.dart' show ImageOptions;
export 'src/saver/file_saver.dart' show FileSaver;
export 'src/saver/save_location.dart'
    show SaveLocation, SavedAtPath, SavedByBrowser;
export 'src/sharer/share_file.dart' show ShareFile;
export 'src/sharer/share_origin.dart' show ShareOrigin;
export 'src/sharer/sharer.dart' show Sharer;

// ── Results — sealed; pattern-match on the variants ──────────────────
export 'src/types/platform_result.dart';

// ── Picked assets ────────────────────────────────────────────────────
export 'src/picker/picked_asset.dart' show PickedAsset;

// ── MIME ↔ extension helpers ─────────────────────────────────────────
export 'src/types/mime_types.dart';
