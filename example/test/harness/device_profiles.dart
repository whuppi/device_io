// Device profiles for the host-VM journey matrix. The on-device
// integration suite can't resize the viewport, so layout proof lives in
// the journeys — a small-screen regression fails locally on every run,
// never first in CI.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class DeviceProfile {
  const DeviceProfile(this.name, this.logicalSize, this.devicePixelRatio);

  final String name;
  final Size logicalSize;
  final double devicePixelRatio;
}

/// Smallest first — the phone-small profile is tighter than any CI
/// emulator and is where layout overflows show up first.
const deviceProfiles = [
  DeviceProfile('phone-small', Size(320, 568), 2),
  DeviceProfile('phone', Size(390, 844), 3),
  DeviceProfile('tablet', Size(1024, 1366), 2),
];

/// Applies [profile] to the test viewport; restored automatically.
void applyProfile(WidgetTester tester, DeviceProfile profile) {
  tester.view.physicalSize = profile.logicalSize * profile.devicePixelRatio;
  tester.view.devicePixelRatio = profile.devicePixelRatio;
  addTearDown(tester.view.reset);
}

/// Bounded settle: pumps a fixed number of frames, draining microtasks
/// between each. Unlike `pumpAndSettle` (which waits for zero scheduled
/// frames and hangs to its 10-minute default when real async I/O keeps
/// the pipeline warm), this always returns — the journeys mix real file
/// I/O with widget pumps, so a fixed budget is both enough and safe.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
