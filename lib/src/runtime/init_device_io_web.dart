import 'package:device_io/src/download/web/web_download_adapter.dart';
import 'package:device_io/src/opener/web/web_file_opener_adapter.dart';
import 'package:device_io/src/picker/web/web_asset_picker_adapter.dart';
import 'package:device_io/src/runtime/device_io.dart';
import 'package:device_io/src/sharing/web/web_sharing_adapter.dart';
import 'package:device_io/src/types/device_io_config.dart';

/// Initialize device IO with web browser adapters.
///
/// [config] is accepted for signature parity; the browser decides download
/// locations, so `downloadSubfolder` has no effect here.
Future<DeviceIO> initDeviceIO({
  DeviceIOConfig config = const DeviceIOConfig(),
}) async {
  return DeviceIO(
    assetPicker: WebAssetPickerAdapter(),
    sharing: WebSharingAdapter(),
    download: WebDownloadAdapter(),
    fileOpener: WebFileOpenerAdapter(),
  );
}
