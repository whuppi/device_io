// CHARTER — this file alone proves: DeviceIOConfig is const-constructible,
// carries the downloadsSubfolder it was given, and defaults it to null.
// Diet: inline literals declared in this file.

import 'package:device_io/src/types/device_io_config.dart';
import 'package:test/test.dart';

import '../harness/timeouts.dart';

void main() {
  const kSubfolder = 'MyApp';

  test('carries the downloadsSubfolder it was constructed with', () {
    const config = DeviceIOConfig(downloadsSubfolder: kSubfolder);
    expect(config.downloadsSubfolder, kSubfolder);
  }, timeout: t(1));

  test('downloadsSubfolder defaults to null', () {
    const config = DeviceIOConfig();
    expect(config.downloadsSubfolder, isNull);
  }, timeout: t(1));

  test(
    'is const-constructible — identical const instances are canonical',
    () {
      const a = DeviceIOConfig(downloadsSubfolder: kSubfolder);
      const b = DeviceIOConfig(downloadsSubfolder: kSubfolder);
      expect(identical(a, b), isTrue);
    },
    timeout: t(1),
  );
}
