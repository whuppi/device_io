// CHARTER — this file alone proves: a PathProviderPlatform can be swapped
// for a fake whose downloads/documents/temp answers are settable per test
// (including the downloads-is-null case that drives the documents fallback),
// and whose downloads lookup can be made to throw so Error-rethrow physics
// are exercisable. It records nothing itself — the adapters' real on-disk
// effect under these paths is what the suites assert against.
//
// Diet: no filesystem imports (pure String path answers), no plugin barrels —
// only the path_provider platform INTERFACE plus the mock mixin that waives
// the platform-interface token check.

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A [PathProviderPlatform] whose directory answers are plain settable
/// fields pointing at per-test temp dirs.
///
/// [downloadsPath] may be null — that is the real mobile shape and the input
/// the download adapter's documents fallback depends on. Set [downloadsError]
/// to make [getDownloadsPath] throw (an `Error` there must be rethrown, not
/// wrapped, by the adapter).
final class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider({
    this.downloadsPath,
    this.documentsPath,
    this.temporaryPath,
    this.downloadsError,
  });

  /// The Downloads directory path, or null to force the documents fallback.
  String? downloadsPath;

  /// The application documents directory path.
  String? documentsPath;

  /// The OS temporary/cache directory path (used for staging).
  String? temporaryPath;

  /// When non-null, [getDownloadsPath] throws this instead of returning.
  Object? downloadsError;

  @override
  Future<String?> getDownloadsPath() async {
    if (downloadsError != null) throw downloadsError!;
    return downloadsPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
