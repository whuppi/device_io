import 'package:device_io/src/picker/asset_picker_adapter.dart';
import 'package:device_io/src/download/download_adapter.dart';
import 'package:device_io/src/opener/file_opener_adapter.dart';
import 'package:device_io/src/sharing/sharing_adapter.dart';

/// Central device IO coordinator.
///
/// Holds all device interaction adapters. Access device capabilities
/// through this class — never via image_picker, share_plus, or other
/// platform packages directly.
///
/// Constructed per-platform:
/// - Native (iOS/Android/macOS/Windows/Linux): dart:io-based adapters
/// - Web: browser API adapters (file input, Web Share, blob URLs)
class DeviceIO {
  /// Image/file picking from device gallery, camera, or file system.
  final AssetPickerAdapter assetPicker;

  /// Share text/files via OS share sheet or Web Share API.
  final SharingAdapter sharing;

  /// Save files to device downloads or trigger browser download.
  final DownloadAdapter download;

  /// Open files in the OS default viewer (Preview, Photos, etc.).
  final FileOpenerAdapter fileOpener;

  const DeviceIO({
    required this.assetPicker,
    required this.sharing,
    required this.download,
    required this.fileOpener,
  });
}
