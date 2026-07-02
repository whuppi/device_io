import 'package:device_io/src/device_io_container.dart';
import 'package:device_io/src/picker/web/web_asset_picker_adapter.dart';
import 'package:device_io/src/download/web/web_download_adapter.dart';
import 'package:device_io/src/opener/web/web_file_opener_adapter.dart';
import 'package:device_io/src/sharing/web/web_sharing_adapter.dart';

/// Initialize device IO with web browser adapters.
Future<DeviceIO> initDeviceIO({
  String? downloadSubfolder,
}) async {
  return DeviceIO(
    assetPicker: WebAssetPickerAdapter(),
    sharing: WebSharingAdapter(),
    download: WebDownloadAdapter(),
    fileOpener: WebFileOpenerAdapter(),
  );
}
