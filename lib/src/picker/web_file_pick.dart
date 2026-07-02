// The platform seam for lazy web file picks. The STUB is deliberately the
// default export: the default is what pub.dev's analyzer attributes to
// every platform, so a package:web default would mark the package web-only
// and drop native. Web resolves to the File System Access implementation;
// every other platform gets the stub, which returns null to fall through.
export 'web_file_pick_stub.dart'
    if (dart.library.js_interop) 'web_file_pick_web.dart';
