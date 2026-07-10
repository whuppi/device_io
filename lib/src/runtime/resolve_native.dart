import 'package:device_io/src/opener/native/file_opener.dart';
import 'package:device_io/src/picker/plugin_asset_picker.dart';
import 'package:device_io/src/runtime/device_io.dart';
import 'package:device_io/src/saver/native/file_saver.dart';
import 'package:device_io/src/sharer/native/sharer.dart';
import 'package:device_io/src/types/device_io_config.dart';

/// Native (dart:io) capability set.
DeviceIO resolveDeviceIO({required DeviceIOConfig config}) {
  return DeviceIO.custom(
    picker: PluginAssetPicker(),
    sharer: NativeSharer(),
    saver: NativeFileSaver(downloadsSubfolder: config.downloadsSubfolder),
    opener: NativeFileOpener(),
  );
}
