import 'package:device_io/device_io.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformResult', () {
    group('PlatformSupported', () {
      test('isSupported is true', () {
        const result = PlatformSupported(42);
        expect(result.isSupported, isTrue);
        expect(result.isCancelled, isFalse);
        expect(result.isUnsupported, isFalse);
        expect(result.isFailed, isFalse);
      });

      test('valueOrNull returns the value', () {
        const result = PlatformSupported('hello');
        expect(result.valueOrNull, 'hello');
      });

      test('when calls supported callback', () {
        const result = PlatformSupported(10);
        final output = result.when(
          supported: (v) => 'got $v',
          cancelled: () => 'cancelled',
          unsupported: (r) => 'unsupported: $r',
          failed: (m, e) => 'failed: $m',
        );
        expect(output, 'got 10');
      });

      test('map transforms the value', () {
        const result = PlatformSupported(5);
        final mapped = result.map((v) => v * 2);
        expect((mapped as PlatformSupported<int>).value, 10);
      });

      test('supports null value', () {
        const PlatformResult<String?> result = PlatformSupported(null);
        expect(result.isSupported, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('PlatformCancelled', () {
      test('isCancelled is true', () {
        const result = PlatformCancelled<int>();
        expect(result.isCancelled, isTrue);
        expect(result.isSupported, isFalse);
        expect(result.isUnsupported, isFalse);
        expect(result.isFailed, isFalse);
      });

      test('valueOrNull returns null', () {
        const result = PlatformCancelled<int>();
        expect(result.valueOrNull, isNull);
      });

      test('when calls cancelled callback', () {
        const result = PlatformCancelled<int>();
        final output = result.when(
          supported: (v) => 'got $v',
          cancelled: () => 'user changed their mind',
          unsupported: (r) => 'unsupported: $r',
          failed: (m, e) => 'failed: $m',
        );
        expect(output, 'user changed their mind');
      });

      test('map re-types the cancellation', () {
        const PlatformResult<int> result = PlatformCancelled();
        final mapped = result.map((v) => '$v');
        expect(mapped, isA<PlatformCancelled<String>>());
      });
    });

    group('PlatformUnsupported', () {
      test('isUnsupported is true', () {
        const result = PlatformUnsupported<int>('No camera on web');
        expect(result.isUnsupported, isTrue);
        expect(result.isSupported, isFalse);
        expect(result.isFailed, isFalse);
      });

      test('valueOrNull returns null', () {
        const result = PlatformUnsupported<int>('reason');
        expect(result.valueOrNull, isNull);
      });

      test('when calls unsupported callback', () {
        const result = PlatformUnsupported<int>('No camera');
        final output = result.when(
          supported: (v) => 'got $v',
          cancelled: () => 'cancelled',
          unsupported: (r) => 'unsupported: $r',
          failed: (m, e) => 'failed: $m',
        );
        expect(output, 'unsupported: No camera');
      });
    });

    group('PlatformFailed', () {
      test('isFailed is true', () {
        const result = PlatformFailed<int>('Disk full');
        expect(result.isFailed, isTrue);
        expect(result.isSupported, isFalse);
        expect(result.isUnsupported, isFalse);
      });

      test('valueOrNull returns null', () {
        const result = PlatformFailed<int>('error');
        expect(result.valueOrNull, isNull);
      });

      test('when calls failed callback', () {
        final result = PlatformFailed<int>(
          'Disk full',
          error: Exception('no space'),
        );
        final output = result.when(
          supported: (v) => 'got $v',
          cancelled: () => 'cancelled',
          unsupported: (r) => 'unsupported: $r',
          failed: (m, e) => 'failed: $m ($e)',
        );
        expect(output, contains('Disk full'));
      });

      test('error is optional', () {
        const result = PlatformFailed<int>('Something went wrong');
        expect(result.error, isNull);
      });
    });

    group('PlatformPermissionDenied', () {
      test('is a PlatformFailed', () {
        const result = PlatformPermissionDenied<int>();
        expect(result, isA<PlatformFailed<int>>());
        expect(result.isFailed, isTrue);
        expect(result.message, 'Permission denied');
      });

      test('generic PlatformFailed handling still catches it', () {
        const PlatformResult<int> result = PlatformPermissionDenied();
        final output = result.when(
          supported: (v) => 'got $v',
          cancelled: () => 'cancelled',
          unsupported: (r) => 'unsupported: $r',
          failed: (m, e) => 'failed: $m',
        );
        expect(output, 'failed: Permission denied');
      });

      test('pattern matching can single it out before PlatformFailed', () {
        const PlatformResult<int> result = PlatformPermissionDenied();
        final output = switch (result) {
          PlatformSupported() => 'value',
          PlatformCancelled() => 'cancelled',
          PlatformUnsupported() => 'unsupported',
          PlatformPermissionDenied() => 'go to settings',
          PlatformFailed() => 'generic failure',
        };
        expect(output, 'go to settings');
      });

      test('map preserves the permission-denied type', () {
        const PlatformResult<int> result = PlatformPermissionDenied(
          message: 'Camera blocked',
        );
        final mapped = result.map((v) => '$v');
        expect(mapped, isA<PlatformPermissionDenied<String>>());
        expect(
          (mapped as PlatformPermissionDenied<String>).message,
          'Camera blocked',
        );
      });
    });

    group('pattern matching', () {
      test('switch covers every variant', () {
        String describe(PlatformResult<int> result) => switch (result) {
          PlatformSupported(:final value) => 'value: $value',
          PlatformCancelled() => 'cancelled',
          PlatformUnsupported(:final reason) => 'unsupported: $reason',
          PlatformFailed(:final message) => 'failed: $message',
        };

        expect(describe(const PlatformSupported(42)), 'value: 42');
        expect(describe(const PlatformCancelled()), 'cancelled');
        expect(
          describe(const PlatformUnsupported('nope')),
          'unsupported: nope',
        );
        expect(describe(const PlatformFailed('boom')), 'failed: boom');
        expect(
          describe(const PlatformPermissionDenied()),
          'failed: Permission denied',
          reason: 'permission denial matches the PlatformFailed arm',
        );
      });
    });

    group('map preserves the variant', () {
      test('unsupported stays unsupported with its reason', () {
        const PlatformResult<int> result = PlatformUnsupported('no camera');
        final mapped = result.map((v) => '$v');
        expect(mapped, isA<PlatformUnsupported<String>>());
        expect((mapped as PlatformUnsupported<String>).reason, 'no camera');
      });

      test('failed stays failed with message and error', () {
        final cause = StateError('boom');
        final PlatformResult<int> result = PlatformFailed(
          'Disk full',
          error: cause,
        );
        final mapped = result.map((v) => '$v');
        expect(mapped, isA<PlatformFailed<String>>());
        final failed = mapped as PlatformFailed<String>;
        expect(failed.message, 'Disk full');
        expect(failed.error, same(cause));
      });

      test('transform is not invoked for non-success variants', () {
        var calls = 0;
        int count(int v) {
          calls++;
          return v;
        }

        const PlatformCancelled<int>().map(count);
        const PlatformUnsupported<int>('nope').map(count);
        const PlatformFailed<int>('boom').map(count);
        expect(calls, 0);
      });
    });

    group('toString', () {
      test('each variant names itself', () {
        expect(
          const PlatformSupported<int>(42).toString(),
          'PlatformSupported(42)',
        );
        expect(
          const PlatformCancelled<int>().toString(),
          'PlatformCancelled()',
        );
        expect(
          const PlatformUnsupported<int>('nope').toString(),
          'PlatformUnsupported(nope)',
        );
        expect(
          const PlatformFailed<int>('boom').toString(),
          'PlatformFailed(boom)',
        );
        expect(
          const PlatformPermissionDenied<int>().toString(),
          'PlatformPermissionDenied(Permission denied)',
        );
      });
    });
  });
}
