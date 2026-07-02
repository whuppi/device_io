// CHARTER — this journey alone proves, across every device profile: the
// example app builds and lays out without overflow; all four capability
// tabs are present and switchable; each tab shows its key action buttons;
// and the global activity log renders below the tabs on every one.
// Diet: the real app widget over a real initDeviceIO(); no plugin edges
// are reached (structure only, nothing tapped that calls a plugin).

import 'package:device_io/device_io.dart';
import 'package:flutter/material.dart';
import 'package:device_io_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/device_profiles.dart';

void main() {
  late DeviceIO deviceIO;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    deviceIO = await initDeviceIO();
  });

  for (final profile in deviceProfiles) {
    testWidgets('structure on ${profile.name}', (tester) async {
      applyProfile(tester, profile);
      await tester.pumpWidget(DeviceIOExampleApp(deviceIO: deviceIO));
      await settle(tester);

      // Four tabs (the label lives on a Tab; a same-named _Section title
      // sits in the body, so target the Tab specifically), global log
      // placeholder.
      for (final tab in ['Pick', 'Share', 'Save', 'Open']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
      expect(find.text('No activity yet.'), findsOneWidget);

      // Each tab switches and shows its key buttons; the log stays visible.
      const perTab = {
        'Pick': ['pickImage', 'pickImages', 'pickFiles'],
        'Share': ['shareText', 'shareFiles (CSV + text)'],
        'Save': ['saveToDevice (CSV)', 'saveAs'],
        'Open': ['openBytes', 'openPath (last saved)'],
      };
      for (final entry in perTab.entries) {
        await tester.tap(find.widgetWithText(Tab, entry.key));
        await settle(tester);
        for (final button in entry.value) {
          expect(find.widgetWithText(Tab, button), findsNothing);
          expect(find.text(button), findsOneWidget, reason: entry.key);
        }
        expect(find.text('No activity yet.'), findsOneWidget);
      }
    });
  }
}
