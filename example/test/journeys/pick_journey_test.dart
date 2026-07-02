// CHARTER — this journey alone proves the pick flow END TO END through the
// example UI, entirely in memory: tapping pickImage runs the real adapter
// against a scripted platform edge and (a) a picked asset appears as a tile
// that reads its bytes ONLY when tapped (the lazy contract, observed
// through the UI); (b) a scripted null logs "cancelled"; (c) image_picker's
// real denied code logs the permission-denied hint. Diet: in-memory bytes
// via XFile.fromData; the FakeImagePickerPlatform edge. No dart:io — real
// filesystem effects live in integration_test.

import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:device_io_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../harness/device_profiles.dart' show settle;
import '../harness/fakes.dart';

void main() {
  late DeviceIO deviceIO;
  late FakeImagePickerPlatform fakePicker;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    deviceIO = await initDeviceIO();
  });

  setUp(() {
    fakePicker = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakePicker;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
    await settle(tester);
  }

  testWidgets('picked asset becomes a tile; bytes read on tap only', (
    tester,
  ) async {
    const declaredLength = 100;
    fakePicker
      ..xfileBytes = Uint8List.fromList(
        List.generate(declaredLength, (i) => i % 251),
      )
      ..xfileName = 'shot.png';

    await pumpApp(tester);
    await tester.tap(find.text('pickImage'));
    await settle(tester);

    // The tile is there, lazily — nothing read yet.
    expect(find.text('shot.png'), findsOneWidget);
    expect(find.textContaining('tap to read bytes'), findsOneWidget);
    expect(find.textContaining('$declaredLength bytes'), findsNothing);

    // Reading happens on tap, and reports the declared length.
    await tester.tap(find.text('shot.png'));
    await settle(tester);
    expect(find.textContaining('$declaredLength bytes'), findsOneWidget);
  });

  testWidgets('scripted null logs cancelled', (tester) async {
    fakePicker.xfileBytes = null;

    await pumpApp(tester);
    await tester.tap(find.text('pickImage'));
    await settle(tester);

    expect(find.textContaining('Pick image → cancelled'), findsOneWidget);
  });

  testWidgets('denied code logs the permission hint', (tester) async {
    fakePicker.error = photoAccessDenied();

    await pumpApp(tester);
    await tester.tap(find.text('pickImage'));
    await settle(tester);

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.textContaining('Open Settings'), findsOneWidget);
  });
}
