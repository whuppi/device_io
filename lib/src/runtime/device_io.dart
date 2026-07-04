import 'package:device_io/src/opener/file_opener.dart';
import 'package:device_io/src/picker/asset_picker.dart';
import 'package:device_io/src/runtime/resolve.dart';
import 'package:device_io/src/saver/file_saver.dart';
import 'package:device_io/src/sharer/sharer.dart';
import 'package:device_io/src/types/device_io_config.dart';

/// Central device IO coordinator.
///
/// Holds all device interaction capabilities. Access them through this
/// class — never via image_picker, share_plus, or other platform packages
/// directly.
///
/// Construction is synchronous. The default constructor resolves the right
/// capability set for the current platform (dart:io-backed on native,
/// browser APIs on web). Capability methods use Flutter plugin channels on
/// native — call them after `WidgetsFlutterBinding.ensureInitialized()`.
///
/// ```dart
/// final deviceIO = DeviceIO();
/// final result = await deviceIO.picker.pickImage();
/// ```
final class DeviceIO {
  /// Resolves the platform capability set for the current target.
  factory DeviceIO({DeviceIOConfig config = const DeviceIOConfig()}) =>
      resolveDeviceIO(config: config);

  /// Creates a coordinator from explicit capability implementations —
  /// the injection seam for tests and custom wiring.
  const DeviceIO.custom({
    required this.picker,
    required this.sharer,
    required this.saver,
    required this.opener,
  });

  /// Image/file picking from device gallery, camera, or file system.
  final AssetPicker picker;

  /// Share text/files via OS share sheet or Web Share API.
  final Sharer sharer;

  /// Save files to the device, silently or via a save dialog.
  final FileSaver saver;

  /// Open files in the OS default viewer (Preview, Photos, etc.).
  final FileOpener opener;
}
