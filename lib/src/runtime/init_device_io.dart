export 'init_device_io_stub.dart'
    if (dart.library.io) 'init_device_io_native.dart'
    if (dart.library.js_interop) 'init_device_io_web.dart';
