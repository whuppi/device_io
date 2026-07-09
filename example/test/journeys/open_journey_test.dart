// CHARTER — this journey alone proves the open flow's UI wiring END TO END,
// entirely in memory, through the PUBLIC DeviceIO.custom seam: tapping
// openBytes hands the opener the in-memory text file (name, mimeType,
// bytes) and logs "→ ok"; a Failed verdict logs "→ failed:" without
// crashing the tab; after a save, "openPath (last saved)" routes the SAVED
// path into openPath (the cross-tab wire, observed at the opener). The
// io-bound NativeFileOpener itself is proven in its own charter against the
// pinned open_filex channel protocol. Diet: RecordingFileOpener replies in
// memory; no dart:io.

import 'dart:convert' show utf8;

import 'package:device_io/device_io.dart';
import 'package:device_io_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/device_profiles.dart' show settle;
import '../harness/fakes.dart';

void main() {
  late RecordingFileOpener opener;
  late RecordingFileSaver saver;
  late DeviceIO deviceIO;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    opener = RecordingFileOpener();
    saver = RecordingFileSaver();
    final base = DeviceIO();
    deviceIO = DeviceIO.custom(
      picker: base.picker,
      sharer: base.sharer,
      saver: saver,
      opener: opener,
    );
  });

  Future<void> pumpToOpenTab(WidgetTester tester) async {
    await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
    await settle(tester);
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('openBytes hands the opener the in-memory file and logs ok', (
    tester,
  ) async {
    await pumpToOpenTab(tester);

    await tester.tap(find.text('openBytes'));
    await settle(tester);

    expect(opener.lastFileName, 'hello.txt');
    expect(opener.lastMimeType, 'text/plain');
    expect(utf8.decode(opener.lastBytes!), contains('straight from memory'));
    expect(find.textContaining('Open bytes → ok'), findsOneWidget);
  });

  testWidgets('a Failed open logs failed, never crashes the tab', (
    tester,
  ) async {
    await pumpToOpenTab(tester);
    opener.result = const PlatformFailed('no app for text/plain');

    await tester.tap(find.text('openBytes'));
    await settle(tester);

    expect(
      find.textContaining('Open bytes → failed: no app for text/plain'),
      findsOneWidget,
    );
  });

  testWidgets('open-last-saved routes the saved path into openPath', (
    tester,
  ) async {
    await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.tap(find.text('save (CSV)'));
    await settle(tester);

    await tester.tap(find.text('Open'));
    await settle(tester);
    await tester.tap(find.text('openPath (last saved)'));
    await settle(tester);

    expect(opener.lastPath, '/inmem/save/people.csv');
    expect(find.textContaining('Open last saved → ok'), findsOneWidget);
  });
}
