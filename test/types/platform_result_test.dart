// CHARTER — this file alone proves the PlatformResult vocabulary itself:
// each variant constructs const and pattern-matches exhaustively;
// PermissionDenied IS-A Failed (the subtype every failure-matching arm
// must order around); Success carries its value, Failed its message /
// error / stackTrace, Unsupported its reason. Diet: pure construction —
// no adapters, no fakes; the cross-adapter grammar lives in
// test/batteries/.

import 'package:device_io/src/types/platform_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const success = PlatformSuccess<int>(42);
  const cancelled = PlatformCancelled<int>();
  const unsupported = PlatformUnsupported<int>('no camera on desktop');
  const failed = PlatformFailed<int>('disk full');
  const denied = PlatformPermissionDenied<int>();

  test('exhaustive switch routes every variant to its own arm', () {
    String route(PlatformResult<int> r) => switch (r) {
      PlatformSuccess(:final value) => 'success:$value',
      PlatformCancelled() => 'cancelled',
      PlatformUnsupported(:final reason) => 'unsupported:$reason',
      PlatformPermissionDenied() => 'denied',
      PlatformFailed(:final message) => 'failed:$message',
    };

    expect(route(success), 'success:42');
    expect(route(cancelled), 'cancelled');
    expect(route(unsupported), 'unsupported:no camera on desktop');
    expect(route(failed), 'failed:disk full');
    expect(route(denied), 'denied');
  });

  test('PermissionDenied IS a PlatformFailed — a generic failed arm '
      'catches it when no denied arm exists', () {
    expect(denied, isA<PlatformFailed<int>>());

    final generic = switch (denied as PlatformResult<int>) {
      PlatformSuccess() => 'success',
      PlatformCancelled() => 'cancelled',
      PlatformUnsupported() => 'unsupported',
      PlatformFailed() => 'failed',
    };
    expect(generic, 'failed');
  });

  test('failure carries message, error, and stackTrace', () {
    final trace = StackTrace.current;
    final f = PlatformFailed<void>('boom', error: 'cause', stackTrace: trace);
    expect(f.message, 'boom');
    expect(f.error, 'cause');
    expect(f.stackTrace, same(trace));
  });

  test('toString names the variant for diagnostics', () {
    expect(success.toString(), 'PlatformSuccess(42)');
    expect(cancelled.toString(), 'PlatformCancelled()');
    expect(unsupported.toString(), 'PlatformUnsupported(no camera on desktop)');
    expect(failed.toString(), 'PlatformFailed(disk full)');
    expect(denied.toString(), 'PlatformPermissionDenied(Permission denied)');
  });
}
