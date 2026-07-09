import 'package:device_io/src/opener/web/file_opener.dart';
import 'package:device_io/src/picker/plugin_asset_picker.dart';
import 'package:device_io/src/runtime/device_io.dart';
import 'package:device_io/src/saver/web/file_saver.dart';
import 'package:device_io/src/sharer/web/sharer.dart';
import 'package:device_io/src/types/device_io_config.dart';

/// Web (browser API) capability set.
DeviceIO resolveDeviceIO({required DeviceIOConfig config}) {
  return DeviceIO.custom(
    picker: PluginAssetPicker(),
    sharer: WebSharer(),
    saver: WebFileSaver(),
    opener: WebFileOpener(),
  );
}
