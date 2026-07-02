import 'package:device_io/src/device_io_container.dart';

/// Stub — should never be reached. Conditional imports resolve to
/// native or web before this is used.
Future<DeviceIO> initDeviceIO({
  String? downloadSubfolder,
}) {
  throw UnsupportedError('Platform not supported');
}
