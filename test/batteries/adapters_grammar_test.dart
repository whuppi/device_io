// CHARTER — this file alone proves, through ONE shared spec, that every
// adapter whose corners are injectable at a pure platform-interface seam
// speaks the Outcome grammar (see result_grammar_battery.dart for
// the variant law). It is also the fleet-visible corner TABLE:
//
//   adapter          success  cancel  deny  failure  unsupported
//   PluginAssetPicker   ✓       ✓      ✓      ✓      charter¹
//   NativeSharer        ✓       ✓      —²     ✓        —²
//   NativeFileSaver              deferred³
//   NativeFileOpener             deferred³
//
// ¹ picker's Unsupported corners need file_picker scaffolding — proven in
//   plugin_asset_picker_test.dart.
// ² share_plus reports no permission/capability verdicts on native; those
//   corners do not exist in this adapter's grammar.
// ³ saver and opener grammar corners require real-filesystem or method-
//   channel scaffolding end to end — proven in their io-exempt charters
//   (saver/native/file_saver_test.dart, opener/native/file_opener_test.dart).
//
// Diet: in-memory XFile.fromData bytes; platform-interface fakes from
// ../harness; no channels, no filesystem.

import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/picker/plugin_asset_picker.dart';
import 'package:device_io/src/sharer/native/sharer.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import '../harness/fake_image_picker_platform.dart';
import '../harness/fake_share_platform.dart';
import 'result_grammar_battery.dart';

void main() {
  // ── PluginAssetPicker over the image_picker seam ──
  final fakePicker = FakeImagePickerPlatform();
  final picker = PluginAssetPicker();

  Future<Outcome<Object?>> pick() => picker.pickImage();

  runResultGrammarSuiteRef(
    'PluginAssetPicker.pickImage',
    setUpCorner: () {
      ImagePickerPlatform.instance = fakePicker
        ..single = null
        ..multi = const []
        ..error = null;
    },
    success: () {
      fakePicker.single = XFile.fromData(
        Uint8List.fromList(const [1, 2, 3]),
        name: 'grammar.png',
        mimeType: 'image/png',
      );
      return pick();
    },
    cancel: pick, // scripted null = the plugin's cancel signal
    deny: () {
      fakePicker.error = PlatformException(
        code: 'photo_access_denied',
        message: 'blocked by the OS',
      );
      return pick();
    },
    failure: () {
      fakePicker.error = PlatformException(
        code: 'already_active',
        message: 'another pick is running',
      );
      return pick();
    },
  );

  // ── NativeSharer over the share_plus seam ──
  final fakeShare = FakeSharePlatform();
  final sharer = NativeSharer();

  Future<Outcome<Object?>> share() => sharer.shareText(text: 'grammar probe');

  runResultGrammarSuiteRef(
    'NativeSharer.shareText',
    setUpCorner: () {
      SharePlatform.instance = fakeShare
        ..result = ShareResult.unavailable
        ..throwError = null;
    },
    success: share, // unavailable status maps to Success (documented)
    cancel: () {
      fakeShare.result = const ShareResult('', ShareResultStatus.dismissed);
      return share();
    },
    failure: () {
      fakeShare.throwError = Exception('share channel exploded');
      return share();
    },
  );
}

/// Thin adapter so call sites read as a table row.
void runResultGrammarSuiteRef(
  String adapter, {
  void Function()? setUpCorner,
  Future<Outcome<Object?>> Function()? success,
  Future<Outcome<Object?>> Function()? cancel,
  Future<Outcome<Object?>> Function()? deny,
  Future<Outcome<Object?>> Function()? failure,
  Future<Outcome<Object?>> Function()? unsupported,
}) {
  runResultGrammarSuite(
    adapter,
    GrammarCorners(
      success: success,
      cancel: cancel,
      deny: deny,
      failure: failure,
      unsupported: unsupported,
    ),
    setUpCorner: setUpCorner,
  );
}
