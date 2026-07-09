// CHARTER — this journey alone proves the save flow's UI wiring END TO END,
// entirely in memory, through the PUBLIC DeviceIO.custom seam (itself under
// proof here — the app runs against injected capabilities exactly as the
// docs promise): tapping save (CSV) (a) hands the saver the app's CSV bytes,
// fileName and mimeType, logs the returned path, and ENABLES the
// "openPath (last saved)" button (cross-tab state plumb); (b) a cancelled
// saveAs dialog logs "→ cancelled". The io-bound NativeFileSaver itself is
// proven in its own charter on a real temp dir. Diet: RecordingFileSaver
// replies in memory; no dart:io.

import 'dart:convert' show utf8;

import 'package:device_io/device_io.dart';
import 'package:device_io_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show FilledButton;
import 'package:flutter/services.dart' show MethodChannel;

import '../harness/device_profiles.dart' show settle;
import '../harness/fakes.dart';

void main() {
  late RecordingFileSaver saver;
  late DeviceIO deviceIO;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    saver = RecordingFileSaver();
    final base = DeviceIO();
    deviceIO = DeviceIO.custom(
      picker: base.picker,
      sharer: base.sharer,
      saver: saver,
      opener: RecordingFileOpener(),
    );
  });

  Future<void> pumpToSaveTab(WidgetTester tester) async {
    await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  testWidgets('save (CSV) hands the saver the CSV payload, logs the path, and '
      'enables open-last-saved', (tester) async {
    await pumpToSaveTab(tester);

    await tester.tap(find.text('save (CSV)'));
    await settle(tester);

    expect(saver.lastFileName, 'people.csv');
    expect(saver.lastMimeType, 'text/csv');
    expect(utf8.decode(saver.lastBytes!), contains('Alice,admin'));
    expect(
      find.textContaining('Save CSV → /inmem/save/people.csv'),
      findsOneWidget,
    );

    // The Success(SavedAtPath) plumbs across tabs: open-last-saved arms.
    await tester.tap(find.text('Open'));
    await settle(tester);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('openPath (last saved)'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a cancelled saveAs dialog logs cancelled', (tester) async {
    await pumpToSaveTab(tester);
    saver.result = const Cancelled();

    await tester.tap(find.text('saveAs'));
    await settle(tester);

    expect(find.textContaining('Save as… → cancelled'), findsOneWidget);
  });

  testWidgets(
    'saveInto is disabled until a folder is picked, then hands the saver that '
    'directory',
    (tester) async {
      // A directory pick returns a scripted path; the journey drives the real
      // adapter against file_picker's `dir` channel via a mock.
      const dirChannel = MethodChannel(
        'miguelruivo.flutter.plugins.filepicker',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(dirChannel, (call) async {
            if (call.method == 'dir') return '/chosen/export/dir';
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(dirChannel, null),
      );

      await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
      await settle(tester);

      // Before picking, saveInto is disabled.
      await tester.tap(find.text('Save'));
      await settle(tester);
      final before = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('saveInto (picked folder)'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(before.onPressed, isNull);

      // Pick a folder on the Pick tab.
      await tester.tap(find.text('Pick'));
      await settle(tester);
      await tester.tap(find.text('pickDirectory'));
      await settle(tester);
      expect(
        find.textContaining('Pick directory → /chosen/export/dir'),
        findsOneWidget,
      );

      // saveInto now arms and hands the saver the chosen directory.
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.tap(find.text('saveInto (picked folder)'));
      await settle(tester);
      expect(saver.lastDirectory, '/chosen/export/dir');
      expect(saver.lastFileName, 'into.csv');
    },
  );
}
