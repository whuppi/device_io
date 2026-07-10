/// The DOMException name (a spec constant like `AbortError`) a caught web
/// rejection carries, matched against [known] — or null when none match.
///
/// The proper interop check is `(e as JSAny).isA<DOMException>()`
/// (`dart:js_interop`, Dart 3.4+) — a real `instanceof DOMException`. What
/// makes it unusable HERE is the cast, not the check: `isA` needs the value
/// as a `JSAny`, and `e as JSAny` can THROW on dart2wasm when the caught
/// object isn't a JS value (dart-lang/sdk#56905) — and a `catch (Object e)`
/// after a rejected promise can legitimately hold a plain Dart object. A
/// `DOMException` stringifies as `Name: message` on every backend, and
/// `toString()` never throws, so name-matching the string form is the robust
/// identifier for a heterogeneous catch. (Plain `e is DOMException` is wrong
/// regardless: `package:web` types reify to `JSObject`, which the
/// `invalid_runtime_check_with_js_interop_types` lint flags.)
///
/// Centralized so this one spot changes in a single place if the safe-cast
/// story ever tightens up (dart-lang/sdk#55457 landed the dart2wasm side).
String? domExceptionName(Object error, List<String> known) {
  final text = error.toString();
  for (final name in known) {
    if (text.contains(name)) return name;
  }
  return null;
}
