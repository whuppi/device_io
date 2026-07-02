// CHARTER — this file alone proves: the PlatformResult<T> sealed family's
// physics — each variant round-trips its carried payload; the
// PermissionDenied-is-a-Failed subtype relationship holds under both switch
// arm orders; the is* predicate truth table; valueOrNull; when() routing
// (PermissionDenied → failed, carrying message+error); map()'s
// transform-on-Supported / preserve-exact-variant-otherwise contract
// (PermissionDenied stays PermissionDenied, keeping message/error/stackTrace);
// and each variant's toString mentioning its payload.
// Diet: inline literals declared in this file.

import 'package:device_io/src/types/platform_result.dart';
import 'package:test/test.dart';

import '../harness/timeouts.dart';

void main() {
  // Declared truths — the payloads every assertion checks against.
  const kValue = 42;
  const kReason = 'no camera on desktop';
  const kMessage = 'disk full';
  final kError = StateError('boom');
  final kStack = StackTrace.current;
  const kDeniedMessage = 'photos denied';

  // ── carried-value round-trip ──

  test('PlatformSupported carries its value', () {
    const r = PlatformSupported<int>(kValue);
    expect(r.value, kValue);
  }, timeout: t(2));

  test('PlatformUnsupported carries its reason', () {
    const r = PlatformUnsupported<int>(kReason);
    expect(r.reason, kReason);
  }, timeout: t(2));

  test('PlatformFailed carries message, error, stackTrace', () {
    final r = PlatformFailed<int>(kMessage, error: kError, stackTrace: kStack);
    expect(r.message, kMessage);
    expect(r.error, same(kError));
    expect(r.stackTrace, same(kStack));
  }, timeout: t(2));

  test('PlatformPermissionDenied carries message, error, stackTrace', () {
    final r = PlatformPermissionDenied<int>(
      message: kDeniedMessage,
      error: kError,
      stackTrace: kStack,
    );
    expect(r.message, kDeniedMessage);
    expect(r.error, same(kError));
    expect(r.stackTrace, same(kStack));
  }, timeout: t(2));

  test(
    'PlatformPermissionDenied defaults message to "Permission denied"',
    () {
      const r = PlatformPermissionDenied<int>();
      expect(r.message, 'Permission denied');
    },
    timeout: t(2),
  );

  // ── subtype relationship: PermissionDenied IS a Failed ──

  test('bare PlatformFailed() arm catches a PermissionDenied', () {
    final PlatformResult<int> r = PlatformPermissionDenied<int>(
      message: kDeniedMessage,
    );
    final label = switch (r) {
      PlatformSupported() => 'supported',
      PlatformCancelled() => 'cancelled',
      PlatformUnsupported() => 'unsupported',
      PlatformFailed(:final message) => 'failed:$message',
    };
    expect(label, 'failed:$kDeniedMessage');
  }, timeout: t(2));

  test('a PermissionDenied arm placed first wins over PlatformFailed', () {
    final PlatformResult<int> r = PlatformPermissionDenied<int>(
      message: kDeniedMessage,
    );
    final label = switch (r) {
      PlatformPermissionDenied(:final message) => 'denied:$message',
      PlatformFailed(:final message) => 'failed:$message',
      _ => 'other',
    };
    expect(label, 'denied:$kDeniedMessage');
  }, timeout: t(2));

  test('a plain PlatformFailed does NOT match a PermissionDenied arm', () {
    final PlatformResult<int> r = PlatformFailed<int>(kMessage);
    final label = switch (r) {
      PlatformPermissionDenied(:final message) => 'denied:$message',
      PlatformFailed(:final message) => 'failed:$message',
      _ => 'other',
    };
    expect(label, 'failed:$kMessage');
  }, timeout: t(2));

  // ── is* predicate truth table ──

  test(
    'isSupported/isCancelled/isUnsupported/isFailed across all five',
    () {
      const supported = PlatformSupported<int>(kValue);
      const cancelled = PlatformCancelled<int>();
      const unsupported = PlatformUnsupported<int>(kReason);
      final failed = PlatformFailed<int>(kMessage);
      const denied = PlatformPermissionDenied<int>();

      // (isSupported, isCancelled, isUnsupported, isFailed)
      expect(
        [
          supported.isSupported,
          supported.isCancelled,
          supported.isUnsupported,
          supported.isFailed,
        ],
        [true, false, false, false],
      );
      expect(
        [
          cancelled.isSupported,
          cancelled.isCancelled,
          cancelled.isUnsupported,
          cancelled.isFailed,
        ],
        [false, true, false, false],
      );
      expect(
        [
          unsupported.isSupported,
          unsupported.isCancelled,
          unsupported.isUnsupported,
          unsupported.isFailed,
        ],
        [false, false, true, false],
      );
      expect(
        [
          failed.isSupported,
          failed.isCancelled,
          failed.isUnsupported,
          failed.isFailed,
        ],
        [false, false, false, true],
      );
      // PermissionDenied is a Failed — isFailed is true for it too.
      expect(
        [
          denied.isSupported,
          denied.isCancelled,
          denied.isUnsupported,
          denied.isFailed,
        ],
        [false, false, false, true],
      );
    },
    timeout: t(2),
  );

  // ── valueOrNull ──

  test('valueOrNull returns the value on Supported, null otherwise', () {
    expect(const PlatformSupported<int>(kValue).valueOrNull, kValue);
    expect(const PlatformCancelled<int>().valueOrNull, isNull);
    expect(const PlatformUnsupported<int>(kReason).valueOrNull, isNull);
    expect(PlatformFailed<int>(kMessage).valueOrNull, isNull);
    expect(const PlatformPermissionDenied<int>().valueOrNull, isNull);
  }, timeout: t(2));

  // ── when() routing ──

  test('when routes each variant to its callback', () {
    String route(PlatformResult<int> r) => r.when(
      supported: (v) => 'supported:$v',
      cancelled: () => 'cancelled',
      unsupported: (reason) => 'unsupported:$reason',
      failed: (message, error) => 'failed:$message',
    );

    expect(route(const PlatformSupported<int>(kValue)), 'supported:$kValue');
    expect(route(const PlatformCancelled<int>()), 'cancelled');
    expect(
      route(const PlatformUnsupported<int>(kReason)),
      'unsupported:$kReason',
    );
    expect(route(PlatformFailed<int>(kMessage)), 'failed:$kMessage');
  }, timeout: t(2));

  test(
    'when routes PermissionDenied to failed, passing message + error',
    () {
      final r = PlatformPermissionDenied<int>(
        message: kDeniedMessage,
        error: kError,
      );
      final captured = r.when(
        supported: (_) => fail('should not route to supported'),
        cancelled: () => fail('should not route to cancelled'),
        unsupported: (_) => fail('should not route to unsupported'),
        failed: (message, error) => (message, error),
      );
      expect(captured.$1, kDeniedMessage);
      expect(captured.$2, same(kError));
    },
    timeout: t(2),
  );

  // ── map() ──

  test('map transforms the Supported value', () {
    const r = PlatformSupported<int>(kValue);
    final mapped = r.map((v) => 'n=$v');
    expect(mapped, isA<PlatformSupported<String>>());
    expect((mapped as PlatformSupported<String>).value, 'n=$kValue');
  }, timeout: t(2));

  test('map preserves Cancelled as Cancelled', () {
    const r = PlatformCancelled<int>();
    final mapped = r.map((v) => 'unused');
    expect(mapped, isA<PlatformCancelled<String>>());
  }, timeout: t(2));

  test('map preserves Unsupported and its reason', () {
    const r = PlatformUnsupported<int>(kReason);
    final mapped = r.map((v) => 'unused');
    expect(mapped, isA<PlatformUnsupported<String>>());
    expect((mapped as PlatformUnsupported<String>).reason, kReason);
  }, timeout: t(2));

  test('map preserves a plain Failed with message/error/stackTrace', () {
    final r = PlatformFailed<int>(kMessage, error: kError, stackTrace: kStack);
    final mapped = r.map((v) => 'unused');
    // Must NOT decay into a subtype or lose payload.
    expect(mapped, isA<PlatformFailed<String>>());
    expect(mapped, isNot(isA<PlatformPermissionDenied<String>>()));
    final f = mapped as PlatformFailed<String>;
    expect(f.message, kMessage);
    expect(f.error, same(kError));
    expect(f.stackTrace, same(kStack));
  }, timeout: t(2));

  test(
    'map keeps PermissionDenied a PermissionDenied with full payload',
    () {
      final r = PlatformPermissionDenied<int>(
        message: kDeniedMessage,
        error: kError,
        stackTrace: kStack,
      );
      final mapped = r.map((v) => 'unused');
      // The exact variant is preserved — it does NOT decay to plain Failed.
      expect(mapped, isA<PlatformPermissionDenied<String>>());
      final d = mapped as PlatformPermissionDenied<String>;
      expect(d.message, kDeniedMessage);
      expect(d.error, same(kError));
      expect(d.stackTrace, same(kStack));
    },
    timeout: t(2),
  );

  test('map does not invoke transform for non-Supported variants', () {
    var calls = 0;
    String tf(int v) {
      calls++;
      return 'x';
    }

    const PlatformCancelled<int>().map(tf);
    const PlatformUnsupported<int>(kReason).map(tf);
    PlatformFailed<int>(kMessage).map(tf);
    const PlatformPermissionDenied<int>().map(tf);
    expect(calls, 0);
  }, timeout: t(2));

  // ── toString mentions payload ──

  test('each variant toString mentions its payload', () {
    expect(
      const PlatformSupported<int>(kValue).toString(),
      contains('$kValue'),
    );
    expect(const PlatformCancelled<int>().toString(), contains('Cancelled'));
    expect(
      const PlatformUnsupported<int>(kReason).toString(),
      contains(kReason),
    );
    expect(PlatformFailed<int>(kMessage).toString(), contains(kMessage));
    expect(
      const PlatformPermissionDenied<int>(message: kDeniedMessage).toString(),
      contains(kDeniedMessage),
    );
  }, timeout: t(2));
}
