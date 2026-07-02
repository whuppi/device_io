/// Cross-platform device IO abstraction for Flutter.
///
/// Unified interfaces for image/file picking, sharing, downloading,
/// and opening files. Same API on iOS, Android, macOS, Windows, Linux, and web.
///
/// ## Quick start
///
/// ```dart
/// // Initialize (once, at app startup):
/// final deviceIO = await initDeviceIO(downloadSubfolder: 'MyApp');
///
/// // Pick an image:
/// final result = await deviceIO.assetPicker.pickImage();
///
/// // Share a file:
/// await deviceIO.sharing.shareFile(bytes: bytes, fileName: 'photo.png');
///
/// // Save to downloads:
/// await deviceIO.download.saveToDevice(bytes: bytes, fileName: 'export.csv');
///
/// // Open in external viewer:
/// await deviceIO.fileOpener.openFile(bytes: bytes, fileName: 'doc.pdf');
/// ```
library;

// Container
export 'src/device_io_container.dart';

// Adapter interfaces
export 'src/picker/asset_picker_adapter.dart';
export 'src/sharing/sharing_adapter.dart';
export 'src/download/download_adapter.dart';
export 'src/opener/file_opener_adapter.dart';

// Init (platform-conditional)
export 'src/init_device_io.dart';

// Types
export 'src/types/platform_result.dart';
export 'src/types/mime_types.dart';
