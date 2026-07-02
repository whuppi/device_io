import 'package:test/test.dart';
import 'package:device_io/device_io.dart';

void main() {
  group('PlatformResult', () {
    group('PlatformSupported', () {
      test('isSupported is true', () {
        const result = PlatformSupported(42);
        expect(result.isSupported, isTrue);
        expect(result.isUnsupported, isFalse);
        expect(result.isFailed, isFalse);
      });

      test('valueOrNull returns the value', () {
        const result = PlatformSupported('hello');
        expect(result.valueOrNull, 'hello');
      });

      test('value field is accessible', () {
        const result = PlatformSupported(42);
        expect(result.value, 42);
      });

      test('when calls supported callback', () {
        const result = PlatformSupported(10);
        final output = result.when(
          supported: (v) => 'got $v',
          unsupported: (r) => 'unsupported: $r',
          failed: (m, e) => 'failed: $m',
        );
        expect(output, 'got 10');
      });

      test('map transforms the value', () {
        const result = PlatformSupported(5);
        final mapped = result.map((v) => v * 2);
        expect(mapped.isSupported, isTrue);
        expect((mapped as PlatformSupported).value, 10);
      });

      test('supports null value', () {
        const PlatformResult<String?> result = PlatformSupported(null);
        expect(result.isSupported, isTrue);
        expect(result.valueOrNull, isNull);
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

    group('pattern matching', () {
      test('switch on supported', () {
        final PlatformResult<int> result = const PlatformSupported(42);
        final output = switch (result) {
          PlatformSupported(:final value) => 'value: $value',
          PlatformUnsupported(:final reason) => 'unsupported: $reason',
          PlatformFailed(:final message) => 'failed: $message',
        };
        expect(output, 'value: 42');
      });

      test('switch on unsupported', () {
        final PlatformResult<int> result = const PlatformUnsupported('nope');
        final output = switch (result) {
          PlatformSupported(:final value) => 'value: $value',
          PlatformUnsupported(:final reason) => 'unsupported: $reason',
          PlatformFailed(:final message) => 'failed: $message',
        };
        expect(output, 'unsupported: nope');
      });
    });
  });
}
