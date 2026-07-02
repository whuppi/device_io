// CHARTER — this file alone proves: a SharePlatform can be swapped for a fake
// that RECORDS every ShareParams the sharing adapter hands it and returns a
// scripted ShareResult (or throws a scripted error). The recorded params —
// text, subject, sharePositionOrigin, and the staged XFile list — are what
// the sharing suite asserts the adapter actually built.
//
// Mechanism verified in share_plus_platform_interface-6.1.0:
//   - lib/platform_interface/share_plus_platform.dart:29  `set instance` runs
//     `PlatformInterface.verifyToken`; MockPlatformInterfaceMixin waives it.
//   - :34  `Future<ShareResult> share(ShareParams params)` is the single
//     entry point the adapter calls via `SharePlatform.instance.share(...)`.
//   - :166 `class ShareResult(this.raw, this.status)`;
//     :202 `enum ShareResultStatus { success, dismissed, unavailable }`.
//   - :182 `ShareResult.unavailable` static const.
//
// Diet: no filesystem imports — records object graphs only; no plugin
// barrels — only the share_plus platform INTERFACE plus the mock mixin.

import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A recording [SharePlatform]. Every [share] call appends its [ShareParams]
/// to [received]; the return is [result] unless [throwError] is set.
final class FakeSharePlatform extends SharePlatform
    with MockPlatformInterfaceMixin {
  FakeSharePlatform({
    this.result = const ShareResult('handled', ShareResultStatus.success),
    this.throwError,
  });

  /// The scripted result [share] returns (unless [throwError] fires first).
  ShareResult result;

  /// When non-null, [share] throws this after recording the params.
  Object? throwError;

  /// Every [ShareParams] received, in call order.
  final List<ShareParams> received = [];

  /// The most recent [ShareParams], or null if [share] was never called.
  ShareParams? get lastParams => received.isEmpty ? null : received.last;

  /// How many times [share] has been invoked.
  int get callCount => received.length;

  @override
  Future<ShareResult> share(ShareParams params) async {
    received.add(params);
    if (throwError != null) throw throwError!;
    return result;
  }
}
