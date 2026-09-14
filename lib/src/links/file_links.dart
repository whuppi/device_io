import 'package:device_io/src/links/file_handle.dart';
import 'package:device_io/src/links/file_ref.dart';
import 'package:device_io/src/links/link_budget.dart';
import 'package:device_io/src/links/link_candidate.dart';
import 'package:device_io/src/links/link_failures.dart';
import 'package:device_io/src/types/outcome.dart';

/// Keep a person's files where they are: pick, link in place, open later.
///
/// The picker here is the link door's own — it asks the platform for
/// access it can KEEP (a persistable grant on Android, an in-place URL on
/// Apple platforms, a path on desktop), which the ordinary asset picker
/// does not. Every pick comes back as a [LinkCandidate] carrying a
/// verdict; the caller links the durable ones and copies the rest through
/// [LinkCandidate.readStream], and never learns which platform decided.
///
/// ```dart
/// final picked = await deviceIO.links.pickFiles(allowedExtensions: ['gguf']);
/// if (picked case Success(:final value)) {
///   for (final candidate in value) {
///     switch (candidate.strength) {
///       case LinkStrength.durable:
///         final linked = await deviceIO.links.link(candidate);
///         // store linked.token, linked.displayName, linked.sizeBytes
///       case LinkStrength.session:
///       case LinkStrength.none:
///         await store.write(candidate.readStream()); // the copy path
///     }
///   }
/// }
///
/// // later
/// final opened = await deviceIO.links.open(FileRef.restore(token: t, displayName: n));
/// switch (opened) {
///   case Success(value: FilePathHandle(:final path)): loadByPath(path);
///   case Success(value: FileDescriptorHandle(:final fd)): loadByDescriptor(fd);
///   case LinkTargetMissing(): ...
///   case LinkNotDownloaded(:final startDownload): await startDownload();
///   case LinkPermissionGone(): ...
///   case Failed(): ...
///   case Cancelled(): case Unsupported(): ...
/// }
/// ```
///
/// A handle stays open until [FileHandle.close]; whatever was loaded from
/// it should be finished with first.
abstract interface class FileLinks {
  /// Opens the platform's file picker asking for keepable access, and
  /// returns one candidate per picked file. Empty selection is
  /// [Cancelled]. [allowedExtensions] filters where the platform can
  /// (dot-less, lowercase); elsewhere every file is offered.
  Future<Outcome<List<LinkCandidate>>> pickFiles({
    List<String>? allowedExtensions,
  });

  /// Opens the platform's folder picker and links the folder — ONE grant
  /// for every file under it, now and later. [Unsupported] where a
  /// platform has no folder grants (the web).
  Future<Outcome<FolderRef>> pickFolder();

  /// A file this process can already name — one the app saved itself, or
  /// one a path-based picker handed over — as a candidate, with the same
  /// verdict a pick would carry. [LinkTargetMissing] when nothing is at
  /// [path]; [Unsupported] where files have no paths (the web).
  Future<Outcome<LinkCandidate>> candidateForPath(String path);

  /// Lists the files inside a linked folder as candidates — the folder's
  /// own files, or with [recursive] every file under it, each carrying
  /// its [LinkCandidate.relativeDirectory]. Linking one costs no further
  /// grant.
  Future<Outcome<List<LinkCandidate>>> children(
    FolderRef folder, {
    List<String>? allowedExtensions,
    bool recursive = false,
  });

  /// Makes a candidate's access durable and returns the ref to store.
  /// [LinkNotDurable] for a candidate whose strength is not durable;
  /// [LinkBudgetFull] when the platform's grant budget is at its reserve.
  Future<Outcome<FileRef>> link(LinkCandidate candidate);

  /// Opens a linked file for reading. Typed refusals:
  /// [LinkTargetMissing], [LinkNotDownloaded], [LinkPermissionGone].
  Future<Outcome<FileHandle>> open(FileRef ref);

  /// Releases whatever [link] took. Idempotent; a ref that is already
  /// gone is a [Success].
  Future<Outcome<void>> unlink(FileRef ref);

  /// Releases a folder's grant. Refs to its children stop opening.
  Future<Outcome<void>> unlinkFolder(FolderRef folder);

  /// The platform's grant ledger — how many durable links are held, and
  /// the cap where one exists.
  Future<LinkBudget> budget();
}
