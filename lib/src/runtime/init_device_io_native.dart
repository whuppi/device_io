import 'package:device_io/src/picker/native/native_asset_picker_adapter.dart';
import 'package:device_io/src/download/native/native_download_adapter.dart';
import 'package:device_io/src/opener/native/native_file_opener_adapter.dart';
import 'package:device_io/src/sharing/native/native_sharing_adapter.dart';
import 'package:device_io/src/runtime/device_io.dart';

/// Initialize device IO with native (dart:io) adapters.
///
/// Must be called after `WidgetsFlutterBinding.ensureInitialized()`.
///
/// [downloadSubfolder] is an optional subfolder name within the downloads
/// directory (e.g. 'MyApp'). If null, saves directly to downloads.
Future<DeviceIO> initDeviceIO({String? downloadSubfolder}) async {
  return DeviceIO(
    assetPicker: NativeAssetPickerAdapter(),
    sharing: NativeSharingAdapter(),
    download: NativeDownloadAdapter(appSubfolder: downloadSubfolder),
    fileOpener: NativeFileOpenerAdapter(),
  );
}
