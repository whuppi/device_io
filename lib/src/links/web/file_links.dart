import 'package:device_io/src/links/file_handle.dart';
import 'package:device_io/src/links/file_links.dart';
import 'package:device_io/src/links/file_ref.dart';
import 'package:device_io/src/links/link_budget.dart';
import 'package:device_io/src/links/link_candidate.dart';
import 'package:device_io/src/links/link_failures.dart';
import 'package:device_io/src/links/link_strength.dart';
import 'package:device_io/src/picker/asset_picker.dart';
import 'package:device_io/src/types/outcome.dart';

/// [FileLinks] in the browser: everything picked is readable now and
/// linkable never.
///
/// A browser hands out blobs, not names. Picking rides the ordinary
/// asset picker so an app has ONE flow — every candidate comes back with
/// [LinkStrength.none] and its bytes on [LinkCandidate.readStream]; the
/// copy path is the only path. Linking, opening and folders answer
/// honestly instead of pretending.
final class WebFileLinks implements FileLinks {
  /// Creates the web links door over the picker that does the picking.
  const WebFileLinks({required AssetPicker picker}) : _picker = picker;

  final AssetPicker _picker;

  static const String _reason =
      'A browser keeps no durable handle to a picked file';

  @override
  Future<Outcome<List<LinkCandidate>>> pickFiles({
    List<String>? allowedExtensions,
  }) async {
    final picked = await _picker.pickFiles(
      allowedExtensions: allowedExtensions,
    );
    return switch (picked) {
      Success(:final value) => Success([
        for (final asset in value)
          LinkCandidate(
            displayName: asset.fileName ?? 'file',
            mimeType: asset.mimeType,
            sizeBytes: asset.sizeBytes,
            strength: LinkStrength.none,
            reason: _reason,
            origin: const BlobOrigin(),
            readStream: asset.readStream,
          ),
      ]),
      Cancelled() => const Cancelled(),
      Unsupported(:final reason) => Unsupported(reason),
      PermissionDenied(:final message, :final error, :final stackTrace) =>
        PermissionDenied(
          message: message,
          error: error,
          stackTrace: stackTrace,
        ),
      Failed(:final message, :final error, :final stackTrace) => Failed(
        message,
        error: error,
        stackTrace: stackTrace,
      ),
    };
  }

  @override
  Future<Outcome<FolderRef>> pickFolder() async =>
      const Unsupported('Browsers expose no folder grants');

  @override
  Future<Outcome<LinkCandidate>> candidateForPath(String path) async =>
      const Unsupported('Browsers have no file paths');

  @override
  Future<Outcome<List<LinkCandidate>>> children(
    FolderRef folder, {
    List<String>? allowedExtensions,
    bool recursive = false,
  }) async => const Unsupported('Browsers expose no folder grants');

  @override
  Future<Outcome<FileRef>> link(LinkCandidate candidate) async =>
      const LinkNotDurable(message: _reason);

  @override
  Future<Outcome<FileHandle>> open(FileRef ref) async =>
      const Unsupported('Browsers cannot reopen a picked file');

  @override
  Future<Outcome<void>> unlink(FileRef ref) async => const Success(null);

  @override
  Future<Outcome<void>> unlinkFolder(FolderRef folder) async =>
      const Success(null);

  @override
  Future<LinkBudget> budget() async => const LinkBudget.uncounted();
}
