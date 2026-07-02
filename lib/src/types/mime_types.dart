/// Centralized MIME type ↔ file extension mappings.
///
/// This is the single source of truth for all format knowledge in the app.
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
/// 4. **Outbound** — we read the extension back for display/icon selection
///
/// At step 4 there is no MIME type — re-deriving one from the extension
/// would be a pointless round-trip. The extension is authoritative because
/// we control the write path.
///
/// ## Adding new formats
///
/// Add the MIME type and extension to [_mimeToExt]. The reverse mapping
/// [_extToMime] is derived automatically. Then add the extension to the
/// appropriate category set ([imageExtensions], [audioExtensions], etc.)
/// so that UI code picks the right icon without hardcoding.
library;

/// MIME type → file extension (without leading dot).
///
/// Used by [FileStorageEngine.extensionFromMime] at write time.
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
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'application/vnd.ms-excel': 'xls',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  'application/vnd.ms-powerpoint': 'ppt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
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
/// Falls back to `application/octet-stream` for unknown extensions.
/// Used by asset picker adapters as a fallback when the platform
/// doesn't report a MIME type.
String mimeTypeFromFileName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0) return 'application/octet-stream';
  final ext = fileName.substring(dotIndex + 1).toLowerCase();
  return extensionToMime[ext] ?? 'application/octet-stream';
}

// ── Extension category sets (for UI icon selection) ──

/// Image file extensions recognized by the app.
const Set<String> imageExtensions = {
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic', 'heif',
};

/// Audio file extensions recognized by the app.
const Set<String> audioExtensions = {'mp3', 'wav', 'ogg', 'aac'};

/// Video file extensions recognized by the app.
const Set<String> videoExtensions = {'mp4', 'webm'};

/// Document file extensions recognized by the app.
const Set<String> documentExtensions = {
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  'txt', 'csv', 'md', 'json', 'xml', 'html', 'zip',
};

/// Vector/drawing file extensions recognized by the app.
const Set<String> vectorExtensions = {'svg'};
