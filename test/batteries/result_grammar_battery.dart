// The Outcome grammar, as ONE spec instead of a rule re-proven
// ad-hoc in every adapter charter. An adapter plugs in by providing a
// probe per grammar corner its seam can inject; the battery asserts the
// exact verdict variant and — because every probe runs unwrapped — that
// the surface NEVER throws (an escaping error fails the corner's test).
//
// Variant law pinned here once:
//   user backed out            → Cancelled
//   OS refused permission      → PermissionDenied (a SUBTYPE of
//                                Failed — the failure corner must therefore
//                                assert it is NOT the subtype)
//   capability absent          → Unsupported with a reason
//   anything else went wrong   → Failed with a message
//   it worked                  → Success
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

  final Future<Outcome<Object?>> Function()? success;
  final Future<Outcome<Object?>> Function()? cancel;
  final Future<Outcome<Object?>> Function()? deny;
  final Future<Outcome<Object?>> Function()? failure;
  final Future<Outcome<Object?>> Function()? unsupported;
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
      test('worked → Success', () async {
        expect(await corners.success!(), isA<Success<Object?>>());
      }, timeout: t(3));
    }

    if (corners.cancel != null) {
      test('user backed out → Cancelled', () async {
        expect(await corners.cancel!(), isA<Cancelled<Object?>>());
      }, timeout: t(3));
    }

    if (corners.deny != null) {
      test('permission refused → PermissionDenied', () async {
        final r = await corners.deny!();
        expect(r, isA<PermissionDenied<Object?>>());
        expect((r as PermissionDenied<Object?>).message, isNotEmpty);
      }, timeout: t(3));
    }

    if (corners.failure != null) {
      test(
        'breakage → Failed (and not the PermissionDenied subtype)',
        () async {
          final r = await corners.failure!();
          expect(r, isA<Failed<Object?>>());
          expect(r, isNot(isA<PermissionDenied<Object?>>()));
          expect((r as Failed<Object?>).message, isNotEmpty);
        },
        timeout: t(3),
      );
    }

    if (corners.unsupported != null) {
      test('capability absent → Unsupported with a reason', () async {
        final r = await corners.unsupported!();
        expect(r, isA<Unsupported<Object?>>());
        expect((r as Unsupported<Object?>).reason, isNotEmpty);
      }, timeout: t(3));
    }
  });
}
