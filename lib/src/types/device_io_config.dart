import 'package:meta/meta.dart';

/// Configuration for `DeviceIO`.
///
/// One object instead of loose parameters so new knobs never change the
/// constructor signature.
@immutable
final class DeviceIOConfig {
  /// Creates a configuration. All fields optional.
  const DeviceIOConfig({this.downloadsSubfolder});

  /// Optional subfolder within the downloads directory that
  /// `FileSaver.save` writes into (e.g. 'MyApp' →
  /// Downloads/MyApp/…). If null, saves land directly in the downloads
  /// directory. Ignored on web.
  final String? downloadsSubfolder;
}
