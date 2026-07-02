// Declared-truth byte fixtures. Tests assert against the constants
// declared HERE — never against values re-derived from the code under
// test. Inline Dart source so VM and browser consume identical bytes.

import 'dart:convert';
import 'dart:typed_data';

/// Text with multi-byte UTF-8 — catches byte/char-length confusion.
const utf8SampleText = 'device_io fixture — línes, ünïcode, ✓ done';

/// The UTF-8 encoding of [utf8SampleText].
final Uint8List utf8SampleBytes = Uint8List.fromList(
  utf8.encode(utf8SampleText),
);

/// Deterministic patterned bytes: `byte[i] == i % 251`.
///
/// 251 is prime, so the pattern never aligns with power-of-two chunk
/// sizes — a dropped, duplicated, or reordered chunk always breaks it.
Uint8List patternedBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = i % 251;
  }
  return bytes;
}

/// True when [bytes] is exactly `patternedBytes(bytes.length)` — the
/// full-content integrity check for anything that wrote or streamed
/// patterned bytes.
bool isPatterned(Uint8List bytes) {
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != i % 251) return false;
  }
  return true;
}
