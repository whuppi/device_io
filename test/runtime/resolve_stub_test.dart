// CHARTER — this file alone proves the resolve seam's DEFAULT export: the
// stub throws UnsupportedError with the documented message. The stub being
// the default is load-bearing — pub.dev's analyzer attributes the default
// import to EVERY platform, so a platform-library default would collapse the
// package's platform list. This test pins the throw so the stub is never
// "helpfully" given a real implementation. Diet: direct import of the stub
// file; nothing else runs.

import 'package:device_io/src/runtime/resolve_stub.dart' as stub;
import 'package:device_io/src/types/device_io_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/timeouts.dart';

void main() {
  test('the stub resolver throws UnsupportedError, never resolves', () {
    expect(
      () => stub.resolveDeviceIO(config: const DeviceIOConfig()),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('no platform implementation'),
        ),
      ),
    );
  }, timeout: t(3));
}
