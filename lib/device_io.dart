/// Cross-platform device IO abstraction for Flutter.
///
/// Unified interfaces for image/file picking, sharing, saving to device,
/// and opening files. Same API on iOS, Android, macOS, Windows, Linux,
/// and web.
///
/// ```dart
/// import 'package:device_io/device_io.dart';
///
/// // Initialize (once, at app startup):
/// final deviceIO = await initDeviceIO(downloadSubfolder: 'MyApp');
///
/// // Pick an image:
/// final result = await deviceIO.assetPicker.pickImage();
/// switch (result) {
///   case PlatformSupported(:final value): use(value);
///   case PlatformCancelled(): break;
///   case PlatformUnsupported(:final reason): hideFeature(reason);
///   case PlatformFailed(:final message): showError(message);
/// }
///
/// // Share a file:
/// await deviceIO.sharing.shareFile(bytes: bytes, fileName: 'photo.png');
///
/// // Save to downloads:
/// await deviceIO.download.saveToDevice(bytes: bytes, fileName: 'export.csv');
///
/// // Open in the default viewer (all platforms):
/// await deviceIO.fileOpener.openBytes(bytes: bytes, fileName: 'doc.pdf');
/// ```
library;

// ── The container + platform-resolved factory ────────────────────────
export 'src/runtime/device_io.dart' show DeviceIO;
export 'src/runtime/init_device_io.dart' show initDeviceIO;

// ── Capability contracts ─────────────────────────────────────────────
export 'src/download/download_adapter.dart' show DownloadAdapter;
export 'src/opener/file_opener_adapter.dart' show FileOpenerAdapter;
export 'src/picker/asset_picker_adapter.dart' show AssetPickerAdapter;
export 'src/sharing/sharing_adapter.dart' show SharingAdapter;

// ── Results — sealed; pattern-match on the variants ──────────────────
export 'src/types/platform_result.dart';

// ── Picked assets ────────────────────────────────────────────────────
export 'src/picker/picked_asset.dart' show PickedAsset;

// ── MIME ↔ extension helpers ─────────────────────────────────────────
export 'src/types/mime_types.dart';
