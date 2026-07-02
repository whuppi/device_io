// Shared JS-surface override machinery for the real-browser adapter suites.
//
// The web adapters call a handful of GLOBAL JS functions —
// showSaveFilePicker, showOpenFilePicker, navigator.share/canShare,
// URL.createObjectURL, window.open. To test them BEHAVIORALLY (not just for
// liveness) we install Dart closures as those globals, RECORD what the
// adapter passed, return scripted results, and restore the originals in
// tearDown. Nothing here fakes a green: every override delegates to a real
// scripted outcome the adapter must map correctly.
//
// This helper lives under test/web_runners/ — the only directory the suite
// guards permit package:web + dart:js_interop.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The global object (`globalThis` / `window`) as a mutable [JSObject].
JSObject get windowObj => web.window as JSObject;

/// `navigator` as a mutable [JSObject].
JSObject get navigatorObj => web.window.navigator as JSObject;

/// The `URL` constructor object — `createObjectURL` is a static on it.
JSObject get urlCtor => globalContext.getProperty('URL'.toJS);

/// Installs or removes `name` on `target`, remembering what was where so
/// [restore] can put everything back exactly.
final class PropOverride {
  PropOverride._(this._key, this._removed, {this.installedOn});

  final JSString _key;

  /// Every (owner, priorValue) pair the override stripped — restore
  /// reinstates each on the object it came from.
  final List<(JSObject, JSAny?)> _removed;

  /// The object [install] wrote the replacement onto (null for removes).
  final JSObject? installedOn;

  /// Replace `target[name]` with [value] as an own property.
  static PropOverride install(JSObject target, String name, JSAny value) {
    final key = name.toJS;
    // Record ONLY an existing own property — a prototype-inherited value
    // must not be restored as an own copy (that leftover own property is
    // exactly what breaks a later remove()).
    final removed = <(JSObject, JSAny?)>[
      if (_hasOwn(target, key)) (target, target.getProperty<JSAny?>(key)),
    ];
    target.setProperty(key, value);
    return PropOverride._(key, removed, installedOn: target);
  }

  /// Remove `name` from `target` AND its whole prototype chain (the
  /// "feature absent" path). Instance methods like `navigator.share` live
  /// on `Navigator.prototype`; a prior install/restore may also have left
  /// an own copy on the instance — `hasProperty` finds either, so every
  /// level is stripped and later restored where it was.
  static PropOverride remove(JSObject target, String name) {
    final key = name.toJS;
    final objectCtor = globalContext.getProperty<JSObject>('Object'.toJS);

    final removed = <(JSObject, JSAny?)>[];
    JSAny? cursor = target;
    while (cursor != null) {
      final owner = cursor as JSObject;
      if (_hasOwn(owner, key)) {
        removed.add((owner, owner.getProperty<JSAny?>(key)));
        owner.delete(key);
      }
      cursor = objectCtor.callMethod<JSAny?>('getPrototypeOf'.toJS, owner);
    }
    return PropOverride._(key, removed);
  }

  static bool _hasOwn(JSObject owner, JSString key) => globalContext
      .getProperty<JSObject>('Object'.toJS)
      .callMethod<JSBoolean>('hasOwn'.toJS, owner, key)
      .toDart;

  /// Undo the install/remove: drop the installed value, reinstate every
  /// stripped (owner, prior) pair where it came from.
  void restore() {
    installedOn?.delete(_key);
    for (final (owner, prior) in _removed) {
      owner.setProperty(_key, prior);
    }
  }
}

/// Restores every [PropOverride] in [overrides], newest first.
void restoreAll(List<PropOverride> overrides) {
  for (final o in overrides.reversed) {
    o.restore();
  }
}

/// A genuine resolved JS promise carrying [value].
JSPromise<T> jsResolve<T extends JSAny?>(T value) =>
    Future<T>.value(value).toJS;

/// A genuine rejected JS promise — built with the real `Promise.reject` so
/// the rejection reason propagates exactly as the browser would deliver it.
JSPromise<T> jsReject<T extends JSAny?>(JSAny reason) {
  final promiseCtor = globalContext.getProperty<JSObject>('Promise'.toJS);
  return promiseCtor.callMethod<JSPromise<T>>('reject'.toJS, reason);
}

/// A real DOMException whose `toString()` stringifies as `Name: message` —
/// the shape the adapters match on ([name] like `AbortError`).
web.DOMException domException(String name, [String message = 'scripted']) =>
    web.DOMException(message, name);

/// Reads a string property off a recorded JS object, or null if absent.
String? readString(JSObject obj, String prop) {
  final key = prop.toJS;
  if (!obj.hasProperty(key).toDart) return null;
  final v = obj.getProperty<JSAny?>(key);
  return v == null ? null : (v as JSString).toDart;
}

/// Reads a numeric property (e.g. `Blob.size`) off a recorded JS object.
int readInt(JSObject obj, String prop) =>
    (obj.getProperty<JSNumber>(prop.toJS)).toDartInt;

/// Fully reads a `Blob`/`File`'s bytes back for content assertions.
Future<Uint8List> blobBytes(web.Blob blob) async {
  final buffer = (await blob.arrayBuffer().toDart).toDart;
  return buffer.asUint8List();
}
