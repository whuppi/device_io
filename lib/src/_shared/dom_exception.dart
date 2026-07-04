/// The DOMException name (a spec constant like `AbortError`) a caught web
/// rejection carries, matched against [known] — or null when none match.
///
/// `package:web`'s `DOMException` is an extension type, erased at runtime, so
/// there is no `e is DOMException` guard to lean on. A DOMException stringifies
/// as `Name: message` on every backend (dart2js and dart2wasm alike), so
/// matching the name in that string form is the portable way to identify one.
///
/// This is the single spot that fragility lives in. If a real runtime type
/// guard for `DOMException` ever becomes available, it changes here once and
/// every caller upgrades with it.
String? domExceptionName(Object error, List<String> known) {
  final text = error.toString();
  for (final name in known) {
    if (text.contains(name)) return name;
  }
  return null;
}
