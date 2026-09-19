/// MIME type ↔ file extension lookups.
///
/// The curated tables ([mimeToExtension], [extensionToMime]) and the pure
/// lookups behind them (`mimeTypeForExtension`, `extensionForMimeType`) are
/// [package:virtual_file_store](https://pub.dev/packages/virtual_file_store)'s — the workspace's
/// one canonical copy, kept there so pure-Dart code (which cannot depend on
/// this Flutter plugin package) can share it too. This file adds the
/// filename- and `package:mime`-database-aware layers device_io needs on
/// top: [mimeTypeFromFileName] and [extensionFromMimeType].
///
/// ## Design: Why extensions, not MIME types, on disk
///
/// MIME types are a **transport** concept (HTTP headers, file picker results,
/// data URIs). Once bytes are written to disk, the file extension IS the type
/// identifier — that's how every OS, file browser, and decoder works.
///
/// The flow:
/// 1. **Inbound** — picker/upload gives us a MIME type (`image/png`)
/// 2. **Conversion** — [mimeToExtension] maps it to `"png"`
/// 3. **Storage** — file written as `photo.png` to storage
/// 4. **Outbound** — the extension is read back for display/icon selection
///
/// At step 4 there is no MIME type — re-deriving one from the extension
/// would be a pointless round-trip. The extension is authoritative because
/// the write path is controlled.
///
/// ## Curated maps vs full lookup
///
/// The maps re-exported below are the CURATED set — the formats this
/// package's category sets and consumers commonly branch on. The lookup
/// functions ([mimeTypeFromFileName], [extensionFromMimeType]) consult the
/// curated maps first and fall back to `package:mime`'s full database (~1000
/// entries), so uncommon formats (`.mov`, `.avif`, `.m4a`, ...) still
/// resolve correctly.
///
/// ## Adding new formats
///
/// Add the MIME type and extension to virtual_file_store's `mimeToExtension` (see
/// `virtual_file_store/docs/UPDATING.md`) — this package carries no table of its own.
/// Then add the extension to the appropriate category set
/// ([imageExtensions], [audioExtensions], etc.) so that UI code picks the
/// right icon without hardcoding.
library;

import 'package:mime/mime.dart' as mime;
import 'package:virtual_file_store/virtual_file_store.dart'
    as virtual_file_store;

/// MIME type → file extension (without leading dot) — the curated set.
///
/// Re-exported from virtual_file_store — see the class doc above.
const Map<String, String> mimeToExtension = virtual_file_store.mimeToExtension;

/// File extension → MIME type — the curated set.
///
/// Re-exported from virtual_file_store — see the class doc above.
final Map<String, String> extensionToMime = virtual_file_store.extensionToMime;

/// Infer a MIME type from a filename's extension.
///
/// Consults virtual_file_store's curated `mimeTypeForExtension` first, then
/// `package:mime`'s full database. Falls back to `application/octet-stream`
/// for unknown extensions. Used by asset picker adapters when the platform
/// doesn't report a MIME type.
String mimeTypeFromFileName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0) return 'application/octet-stream';
  final ext = fileName.substring(dotIndex + 1).toLowerCase();
  return virtual_file_store.mimeTypeForExtension(ext) ??
      mime.lookupMimeType(fileName.toLowerCase()) ??
      'application/octet-stream';
}

/// Derive a file extension (without leading dot) from a MIME type.
///
/// Consults virtual_file_store's curated `extensionForMimeType` first, then
/// `package:mime`'s full database. Returns [fallback] when the MIME type is
/// unknown.
String extensionFromMimeType(String mimeType, {String fallback = 'bin'}) {
  return virtual_file_store.extensionForMimeType(mimeType) ??
      mime.extensionFromMime(mimeType) ??
      fallback;
}

// ── Extension category sets (for UI icon selection) ──

/// Image file extensions.
const Set<String> imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'bmp',
  'heic',
  'heif',
};

/// Audio file extensions.
const Set<String> audioExtensions = {'mp3', 'wav', 'ogg', 'aac'};

/// Video file extensions.
const Set<String> videoExtensions = {'mp4', 'webm'};

/// Document file extensions.
const Set<String> documentExtensions = {
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'csv',
  'md',
  'json',
  'xml',
  'html',
  'zip',
};

/// Vector/drawing file extensions.
const Set<String> vectorExtensions = {'svg'};
