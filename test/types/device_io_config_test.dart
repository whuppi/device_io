// CHARTER — this file alone proves: DeviceIOConfig is const-constructible,
// carries the downloadSubfolder it was given, and defaults it to null.
// Diet: inline literals declared in this file.

import 'package:device_io/src/types/device_io_config.dart';
import 'package:test/test.dart';

import '../harness/timeouts.dart';

void main() {
  const kSubfolder = 'MyApp';

  test('carries the downloadSubfolder it was constructed with', () {
    const config = DeviceIOConfig(downloadSubfolder: kSubfolder);
    expect(config.downloadSubfolder, kSubfolder);
  }, timeout: t(1));

  test('downloadSubfolder defaults to null', () {
    const config = DeviceIOConfig();
    expect(config.downloadSubfolder, isNull);
  }, timeout: t(1));

  test(
    'is const-constructible — identical const instances are canonical',
    () {
      const a = DeviceIOConfig(downloadSubfolder: kSubfolder);
      const b = DeviceIOConfig(downloadSubfolder: kSubfolder);
      expect(identical(a, b), isTrue);
    },
    timeout: t(1),
  );
}
