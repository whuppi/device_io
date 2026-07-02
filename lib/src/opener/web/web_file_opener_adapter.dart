import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/opener/file_opener_adapter.dart';

/// Web file opener — not supported.
///
/// Files on web live in IndexedDB, not on a real filesystem.
/// There's no absolute path to open.
class WebFileOpenerAdapter implements FileOpenerAdapter {
  @override
  Future<PlatformResult<void>> openFile({
    required String filePath,
    String? mimeType,
  }) async {
    return const PlatformUnsupported('File opening is not supported on web');
  }
}
