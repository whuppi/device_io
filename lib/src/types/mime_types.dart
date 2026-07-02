/// Centralized MIME type ↔ file extension mappings.
///
/// The single source of truth for format knowledge in this package.
/// Every layer that needs to convert between MIME types and extensions
/// MUST use these mappings — never hardcode extension lists elsewhere.
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
/// The const maps below are the CURATED set — the formats this package's
/// category sets and consumers commonly branch on. The lookup functions
/// ([mimeTypeFromFileName], [extensionFromMimeType]) consult the curated
/// maps first and fall back to `package:mime`'s full database (~1000
/// entries), so uncommon formats (`.mov`, `.avif`, `.m4a`, ...) still
/// resolve correctly.
///
/// ## Adding new formats
///
/// Add the MIME type and extension to [mimeToExtension]. The reverse mapping
/// [extensionToMime] is derived automatically. Then add the extension to the
/// appropriate category set ([imageExtensions], [audioExtensions], etc.)
/// so that UI code picks the right icon without hardcoding.
library;

import 'package:mime/mime.dart' as mime;

/// MIME type → file extension (without leading dot) — the curated set.
///
/// Use at write time to derive an on-disk extension from a picker or
/// transport MIME type. For full-database coverage use
/// [extensionFromMimeType].
const Map<String, String> mimeToExtension = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'image/bmp': 'bmp',
  'image/svg+xml': 'svg',
  'image/heic': 'heic',
  'image/heif': 'heif',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/ogg': 'ogg',
  'audio/aac': 'aac',
  'video/mp4': 'mp4',
  'video/webm': 'webm',
  'application/pdf': 'pdf',
  'application/json': 'json',
  'application/xml': 'xml',
  'application/zip': 'zip',
  'application/msword': 'doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      'docx',
  'application/vnd.ms-excel': 'xls',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  'application/vnd.ms-powerpoint': 'ppt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      'pptx',
  'text/plain': 'txt',
  'text/csv': 'csv',
  'text/markdown': 'md',
  'text/html': 'html',
  'application/octet-stream': 'bin',
};

/// File extension → MIME type.
///
/// Used by asset picker adapters when the platform doesn't provide a MIME type.
/// Derived from [mimeToExtension] with additional aliases (e.g. jpeg → image/jpeg).
final Map<String, String> extensionToMime = {
  for (final entry in mimeToExtension.entries) entry.value: entry.key,
  // Aliases not in the reverse map
  'jpeg': 'image/jpeg',
  'heif': 'image/heic',
};

/// Infer a MIME type from a filename's extension.
///
/// Consults the curated [extensionToMime] map first, then `package:mime`'s
/// full database. Falls back to `application/octet-stream` for unknown
/// extensions. Used by asset picker adapters when the platform doesn't
/// report a MIME type.
String mimeTypeFromFileName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0) return 'application/octet-stream';
  final ext = fileName.substring(dotIndex + 1).toLowerCase();
  return extensionToMime[ext] ??
      mime.lookupMimeType(fileName.toLowerCase()) ??
      'application/octet-stream';
}

/// Derive a file extension (without leading dot) from a MIME type.
///
/// Consults the curated [mimeToExtension] map first, then `package:mime`'s
/// full database. Returns [fallback] when the MIME type is unknown.
String extensionFromMimeType(String mimeType, {String fallback = 'bin'}) {
  return mimeToExtension[mimeType] ??
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
