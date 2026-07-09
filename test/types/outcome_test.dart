// CHARTER — this file alone proves the Outcome vocabulary itself:
// each variant constructs const and pattern-matches exhaustively;
// PermissionDenied IS-A Failed (the subtype every failure-matching arm
// must order around); Success carries its value, Failed its message /
// error / stackTrace, Unsupported its reason. Diet: pure construction —
// no adapters, no fakes; the cross-adapter grammar lives in
// test/batteries/.

import 'package:device_io/src/types/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const success = Success<int>(42);
  const cancelled = Cancelled<int>();
  const unsupported = Unsupported<int>('no camera on desktop');
  const failed = Failed<int>('disk full');
  const denied = PermissionDenied<int>();

  test('exhaustive switch routes every variant to its own arm', () {
    String route(Outcome<int> r) => switch (r) {
      Success(:final value) => 'success:$value',
      Cancelled() => 'cancelled',
      Unsupported(:final reason) => 'unsupported:$reason',
      PermissionDenied() => 'denied',
      Failed(:final message) => 'failed:$message',
    };

    expect(route(success), 'success:42');
    expect(route(cancelled), 'cancelled');
    expect(route(unsupported), 'unsupported:no camera on desktop');
    expect(route(failed), 'failed:disk full');
    expect(route(denied), 'denied');
  });

  test('PermissionDenied IS a Failed — a generic failed arm '
      'catches it when no denied arm exists', () {
    expect(denied, isA<Failed<int>>());

    final generic = switch (denied as Outcome<int>) {
      Success() => 'success',
      Cancelled() => 'cancelled',
      Unsupported() => 'unsupported',
      Failed() => 'failed',
    };
    expect(generic, 'failed');
  });

  test('failure carries message, error, and stackTrace', () {
    final trace = StackTrace.current;
    final f = Failed<void>('boom', error: 'cause', stackTrace: trace);
    expect(f.message, 'boom');
    expect(f.error, 'cause');
    expect(f.stackTrace, same(trace));
  });

  test('toString names the variant for diagnostics', () {
    expect(success.toString(), 'Success(42)');
    expect(cancelled.toString(), 'Cancelled()');
    expect(unsupported.toString(), 'Unsupported(no camera on desktop)');
    expect(failed.toString(), 'Failed(disk full)');
    expect(denied.toString(), 'PermissionDenied(Permission denied)');
  });
}
