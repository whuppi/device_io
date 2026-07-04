// The platform seam. The STUB is deliberately the default export: the
// default is what pub.dev's analyzer attributes to every platform, so a
// dart:io default would mark the package native-only and drop web.
// Real platforms resolve to the native or web implementation.
export 'resolve_stub.dart'
    if (dart.library.io) 'resolve_native.dart'
    if (dart.library.js_interop) 'resolve_web.dart';
