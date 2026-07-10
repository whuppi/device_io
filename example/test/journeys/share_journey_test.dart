// CHARTER — this journey alone proves the share flow END TO END through the
// example UI, entirely in memory: the REAL NativeSharer runs against a
// scripted share_plus platform edge. Tapping shareText (a) hands share_plus
// exactly the app's text + subject and logs "→ ok" on a success status;
// (b) a dismissed ShareResult logs "→ cancelled"; (c) a thrown share edge
// logs "→ failed:". Diet: FakeSharePlatform records ShareParams object
// graphs; no dart:io — file shares stage real bytes and live in
// integration_test.

import 'package:device_io/device_io.dart';
import 'package:device_io_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import '../harness/device_profiles.dart' show settle;
import '../harness/fakes.dart';

void main() {
  late DeviceIO deviceIO;
  late FakeSharePlatform fakeShare;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    deviceIO = DeviceIO();
  });

  setUp(() {
    fakeShare = FakeSharePlatform();
    SharePlatform.instance = fakeShare;
  });

  Future<void> pumpToShareTab(WidgetTester tester) async {
    await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
    await settle(tester);
    await tester.tap(find.text('Share'));
    await settle(tester);
  }

  testWidgets('shareText hands share_plus the app text and logs ok', (
    tester,
  ) async {
    await pumpToShareTab(tester);

    await tester.tap(find.text('shareText'));
    await settle(tester);

    final params = fakeShare.received.single;
    expect(params.text, contains('device_io example app'));
    expect(params.subject, 'device_io');
    expect(find.textContaining('Share text → ok'), findsOneWidget);
  });

  testWidgets('a dismissed share sheet logs cancelled', (tester) async {
    await pumpToShareTab(tester);
    fakeShare.result = const ShareResult('', ShareResultStatus.dismissed);

    await tester.tap(find.text('shareText'));
    await settle(tester);

    expect(find.textContaining('Share text → cancelled'), findsOneWidget);
  });

  testWidgets('a thrown share edge logs failed, never crashes the UI', (
    tester,
  ) async {
    await pumpToShareTab(tester);
    fakeShare.throwError = Exception('share sheet exploded');

    await tester.tap(find.text('shareText'));
    await settle(tester);

    expect(find.textContaining('Share text → failed:'), findsOneWidget);
  });
}
