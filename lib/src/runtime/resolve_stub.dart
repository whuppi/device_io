import 'package:device_io/src/runtime/device_io.dart';
import 'package:device_io/src/types/device_io_config.dart';

/// Stub — should never be reached. Conditional imports resolve to
/// native or web before this is used.
///
/// Present so the default import carries NO platform library — the
/// default is what pub.dev's analyzer attributes to EVERY platform, so a
/// dart:io default would mark the package native-only and drop web.
DeviceIO resolveDeviceIO({required DeviceIOConfig config}) {
  throw UnsupportedError(
    'device_io: no platform implementation for this target',
  );
}
