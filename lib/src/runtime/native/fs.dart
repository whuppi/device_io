// Shared filesystem plumbing for the NATIVE adapters (download, sharing,
// opener). Imports dart:io — never export from the barrel, never import
// from web adapters or shared interfaces.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Hoisted so sanitizeFileName doesn't recompile its patterns per call.
final _unsafeChars = RegExp(r'[/\\<>:"|?*]');
final _controlChars = RegExp(r'[\x00-\x1F\x7F]');
final _trailingDots = RegExp(r'\.+$');
final _onlyDots = RegExp(r'^\.+$');

// Windows refuses these as the part before the first dot ('CON.txt' is as
// invalid as 'CON'), case-insensitively.
const _windowsReservedNames = {
  'con', 'prn', 'aux', 'nul', //
  'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
  'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9',
};

/// Makes a caller-supplied file name safe to interpolate into a filesystem
/// path.
///
/// File names routinely come from untrusted places — picked files, server
/// `Content-Disposition` headers, user input. Without this, a name like
/// `../../evil` escapes the target directory.
///
/// - Path separators and characters Windows forbids become `_`
///   (`/ \ < > : " | ? *`).
/// - Control characters are stripped.
/// - Leading/trailing whitespace and trailing dots are trimmed
///   (Windows rejects both).
/// - Names that sanitize to nothing (including `.` / `..`) become `file`.
/// - Windows reserved device names (`CON`, `NUL`, `COM1`, ... — also as
///   `CON.txt`) get a leading underscore.
/// - Overlong names are truncated to 200 chars, keeping the extension.
String sanitizeFileName(String fileName) {
  var name = fileName
      .replaceAll(_unsafeChars, '_')
      .replaceAll(_controlChars, '')
      .trim();
  name = name.replaceAll(_trailingDots, '');
  if (name.isEmpty || _onlyDots.hasMatch(name)) {
    return 'file';
  }
  final firstDot = name.indexOf('.');
  final base = (firstDot < 0 ? name : name.substring(0, firstDot));
  if (_windowsReservedNames.contains(base.toLowerCase())) {
    name = '_$name';
  }
  if (name.length > 200) {
    final dot = name.lastIndexOf('.');
    // Keep extensions up to 15 chars; anything longer is not a real
    // extension and gets truncated with the stem.
    if (dot > 0 && name.length - dot <= 16) {
      final ext = name.substring(dot);
      name = name.substring(0, 200 - ext.length) + ext;
    } else {
      name = name.substring(0, 200);
    }
  }
  return name;
}

/// Reserves a not-yet-existing file named [fileName] inside [dir],
/// atomically.
///
/// A taken name gets a numbered variant (`report (1).pdf`), matching
/// browser download behavior. The returned file EXISTS (zero bytes) — the
/// atomic `create(exclusive: true)` is what makes two concurrent saves of
/// the same name collision-free; an exists()-then-write check would race.
Future<File> reserveFreshFile(Directory dir, String fileName) async {
  // Split on the LAST dot so multi-dot names keep their final extension.
  // A leading dot (`.hidden`) is part of the stem, not an extension.
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';

  var candidate = File('${dir.path}/$fileName');
  for (var counter = 1; counter <= 1000; counter++) {
    try {
      return await candidate.create(exclusive: true);
    } on PathExistsException {
      candidate = File('${dir.path}/$stem ($counter)$ext');
    }
  }
  // A thousand same-named files means numbering has stopped being useful —
  // a timestamped name keeps the save working instead of looping forever.
  return File(
    '${dir.path}/$stem (${DateTime.now().microsecondsSinceEpoch})$ext',
  ).create(exclusive: true);
}

/// Creates a unique staging directory under the OS cache dir and writes
/// [fileName] into it via [write]. Returns the staged file.
///
/// Every call gets its own directory (atomic `createTemp`, no
/// timestamp-collision window) so concurrent stagings of the same fileName
/// never collide while the real fileName is preserved (share sheets and
/// viewers display it).
///
/// Staged files are deliberately NOT deleted afterwards: share targets and
/// viewers may read them long after the triggering call returns. The OS
/// reclaims its cache directory automatically on both Android and iOS.
Future<File> stageFile({
  required String purpose,
  required String fileName,
  required Future<void> Function(File file) write,
}) async {
  final tempDir = await getTemporaryDirectory();
  final root = await Directory(
    '${tempDir.path}/device_io_$purpose',
  ).create(recursive: true);
  final stagingDir = await root.createTemp();
  final file = File('${stagingDir.path}/${sanitizeFileName(fileName)}');
  await write(file);
  return file;
}

/// Stages several named files into ONE fresh staging directory and returns
/// them in the given order.
///
/// Each entry's name is sanitized; when two entries sanitize to the same
/// name the later ones are numbered (`report (1).pdf`) so nothing is
/// overwritten. Numbering is resolved in memory against the names already
/// claimed in this call — one brand-new `createTemp` directory has no
/// pre-existing files, so there is no filesystem race to guard against.
///
/// Same staging lifecycle as [stageFile]: every call gets its own directory
/// and the files are deliberately NOT deleted, so share targets can read
/// them after the call returns.
Future<List<File>> stageFiles({
  required String purpose,
  required List<({String fileName, Future<void> Function(File file) write})>
  entries,
}) async {
  final tempDir = await getTemporaryDirectory();
  final root = await Directory(
    '${tempDir.path}/device_io_$purpose',
  ).create(recursive: true);
  final stagingDir = await root.createTemp();

  final claimed = <String>{};
  final files = <File>[];
  for (final entry in entries) {
    final name = _uniqueName(sanitizeFileName(entry.fileName), claimed);
    final file = File('${stagingDir.path}/$name');
    await entry.write(file);
    files.add(file);
  }
  return files;
}

/// Returns [name] if unclaimed, otherwise a numbered variant
/// (`report (1).pdf`) that is not yet in [claimed]. Records the result in
/// [claimed] before returning.
// Unlike reserveFreshFile this needs no iteration cap: candidates only race
// the in-memory set, never the filesystem, and every counter yields a new
// distinct string — the loop terminates within claimed.length + 1 steps.
String _uniqueName(String name, Set<String> claimed) {
  if (claimed.add(name)) return name;

  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var counter = 1; ; counter++) {
    final candidate = '$stem ($counter)$ext';
    if (claimed.add(candidate)) return candidate;
  }
}
