import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// The web registrant. Registration is not this package's activation
/// path — `DeviceIO()` resolves the web capability set through its
/// conditional import — but a declared web plugin must name a class the
/// generated registrant can call, and declaring the platform is what
/// tells pub.dev, and the tooling, that the web is supported.
class DeviceIoWeb {
  /// Called by the generated plugin registrant. Nothing to wire.
  static void registerWith(Registrar registrar) {}
}
