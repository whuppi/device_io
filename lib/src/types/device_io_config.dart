import 'package:meta/meta.dart';

/// Configuration for `initDeviceIO`.
///
/// One object instead of loose parameters so new knobs never change the
/// init signature.
@immutable
final class DeviceIOConfig {
  /// Creates a configuration. All fields optional.
  const DeviceIOConfig({this.downloadSubfolder});

  /// Optional subfolder within the downloads directory that
  /// `DownloadAdapter.saveToDevice` writes into (e.g. 'MyApp' →
  /// Downloads/MyApp/…). If null, saves land directly in the downloads
  /// directory. Ignored on web.
  final String? downloadSubfolder;
}
