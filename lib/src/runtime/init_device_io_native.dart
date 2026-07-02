import 'package:device_io/src/download/native/native_download_adapter.dart';
import 'package:device_io/src/opener/native/native_file_opener_adapter.dart';
import 'package:device_io/src/picker/plugin_asset_picker_adapter.dart';
import 'package:device_io/src/runtime/device_io.dart';
import 'package:device_io/src/sharing/native/native_sharing_adapter.dart';
import 'package:device_io/src/types/device_io_config.dart';

/// Initialize device IO with native (dart:io) adapters.
///
/// Must be called after `WidgetsFlutterBinding.ensureInitialized()`.
Future<DeviceIO> initDeviceIO({
  DeviceIOConfig config = const DeviceIOConfig(),
}) async {
  return DeviceIO(
    assetPicker: PluginAssetPickerAdapter(),
    sharing: NativeSharingAdapter(),
    download: NativeDownloadAdapter(appSubfolder: config.downloadSubfolder),
    fileOpener: NativeFileOpenerAdapter(),
  );
}
