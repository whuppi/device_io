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
///   case Success(:final value): use(value);
///   case Cancelled(): break;
///   case Unsupported(:final reason): hideFeature(reason);
///   case Failed(:final message): showError(message);
/// }
///
/// // Share a file:
/// await deviceIO.sharer.shareFile(bytes: bytes, fileName: 'photo.png');
///
/// // Save to downloads, then open what was saved:
/// final saved = await deviceIO.saver.save(bytes: bytes, fileName: 'a.csv');
/// if (saved case Success(value: SavedAtPath(:final path))) {
///   await deviceIO.opener.openPath(filePath: path);
/// }
///
/// // Open in the default viewer (all platforms):
/// await deviceIO.opener.openBytes(bytes: bytes, fileName: 'doc.pdf');
///
/// // Keep a large file where it is instead of copying it:
/// final picked = await deviceIO.links.pickFiles(allowedExtensions: ['gguf']);
/// if (picked case Success(value: [final candidate, ...])) {
///   final linked = await deviceIO.links.link(candidate); // when durable
/// }
///
/// // Read, write, list, and delete objects inside a linked folder:
/// final folder = await deviceIO.links.pickFolder();
/// if (folder case Success(:final value)) {
///   await deviceIO.folders.write(value, 'manifest.json', bytes);
/// }
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

// ── Links — keep files where they are ────────────────────────────────
export 'src/links/file_handle.dart'
    show FileHandle, FilePathHandle, FileDescriptorHandle;
export 'src/links/file_links.dart' show FileLinks;
export 'src/links/file_ref.dart' show FileRef, FolderRef;
export 'src/links/folder_io.dart' show FolderIo;
export 'src/links/link_budget.dart' show LinkBudget;
export 'src/links/link_candidate.dart' show LinkCandidate;
export 'src/links/link_failures.dart'
    show
        LinkTargetMissing,
        LinkNotDownloaded,
        LinkPermissionGone,
        LinkBudgetFull,
        LinkNotDurable,
        LinkReadError;
export 'src/links/link_strength.dart' show LinkStrength;

// ── Results — sealed; pattern-match on the variants ──────────────────
export 'src/types/outcome.dart';

// ── Plugin registrant for Linux / Windows (called by generated code) ──
export 'src/registrants/device_io_desktop.dart' show DeviceIoDesktop;

// ── Picked assets ────────────────────────────────────────────────────
export 'src/picker/picked_asset.dart' show PickedAsset;

// ── MIME ↔ extension helpers ─────────────────────────────────────────
export 'src/types/mime_types.dart';
