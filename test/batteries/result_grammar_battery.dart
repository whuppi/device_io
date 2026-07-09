// The PlatformResult grammar, as ONE spec instead of a rule re-proven
// ad-hoc in every adapter charter. An adapter plugs in by providing a
// probe per grammar corner its seam can inject; the battery asserts the
// exact verdict variant and — because every probe runs unwrapped — that
// the surface NEVER throws (an escaping error fails the corner's test).
//
// Variant law pinned here once:
//   user backed out            → PlatformCancelled
//   OS refused permission      → PlatformPermissionDenied (a SUBTYPE of
//                                Failed — the failure corner must therefore
//                                assert it is NOT the subtype)
//   capability absent          → PlatformUnsupported with a reason
//   anything else went wrong   → PlatformFailed with a message
//   it worked                  → PlatformSuccess
//
// Adapters whose corners cannot be injected through a pure platform-
// interface seam (real filesystem or channel scaffolding required) keep
// their grammar proofs in their own io-exempt charters; the instantiation
// table in adapters_grammar_test.dart names each deferral and why.

import 'package:device_io/device_io.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/timeouts.dart';

/// One probe per grammar corner an adapter's seam can inject. Null means
/// "not injectable through this adapter's seam" — the corner is then
/// covered by the adapter's own charter, not silently dropped: the
/// instantiation file's table says where it lives instead.
final class GrammarCorners {
  const GrammarCorners({
    this.success,
    this.cancel,
    this.deny,
    this.failure,
    this.unsupported,
  });

  final Future<PlatformResult<Object?>> Function()? success;
  final Future<PlatformResult<Object?>> Function()? cancel;
  final Future<PlatformResult<Object?>> Function()? deny;
  final Future<PlatformResult<Object?>> Function()? failure;
  final Future<PlatformResult<Object?>> Function()? unsupported;
}

/// Generates the grammar suite for one adapter. [setUpCorner] runs before
/// every corner (install fresh fakes); the probes run unwrapped so any
/// escaping throw fails the corner outright.
void runResultGrammarSuite(
  String adapter,
  GrammarCorners corners, {
  void Function()? setUpCorner,
}) {
  group('$adapter — result grammar', () {
    if (setUpCorner != null) setUp(setUpCorner);

    if (corners.success != null) {
      test('worked → PlatformSuccess', () async {
        expect(await corners.success!(), isA<PlatformSuccess<Object?>>());
      }, timeout: t(3));
    }

    if (corners.cancel != null) {
      test('user backed out → PlatformCancelled', () async {
        expect(await corners.cancel!(), isA<PlatformCancelled<Object?>>());
      }, timeout: t(3));
    }

    if (corners.deny != null) {
      test('permission refused → PlatformPermissionDenied', () async {
        final r = await corners.deny!();
        expect(r, isA<PlatformPermissionDenied<Object?>>());
        expect((r as PlatformPermissionDenied<Object?>).message, isNotEmpty);
      }, timeout: t(3));
    }

    if (corners.failure != null) {
      test(
        'breakage → PlatformFailed (and not the PermissionDenied subtype)',
        () async {
          final r = await corners.failure!();
          expect(r, isA<PlatformFailed<Object?>>());
          expect(r, isNot(isA<PlatformPermissionDenied<Object?>>()));
          expect((r as PlatformFailed<Object?>).message, isNotEmpty);
        },
        timeout: t(3),
      );
    }

    if (corners.unsupported != null) {
      test('capability absent → PlatformUnsupported with a reason', () async {
        final r = await corners.unsupported!();
        expect(r, isA<PlatformUnsupported<Object?>>());
        expect((r as PlatformUnsupported<Object?>).reason, isNotEmpty);
      }, timeout: t(3));
    }
  });
}
