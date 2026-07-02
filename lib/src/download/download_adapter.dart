import 'dart:typed_data';

import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic file saving to the device.
///
/// Implementations:
/// - `NativeDownloadAdapter` — writes to the downloads directory
///   (mobile/desktop)
/// - `WebDownloadAdapter` — triggers a browser download via blob URL (web)
abstract interface class DownloadAdapter {
  /// Save bytes without user interaction.
  ///
  /// Where the file lands:
  /// - **Desktop**: the user's real Downloads folder.
  /// - **Mobile**: an app-private downloads folder
  ///   (`Android/data/<pkg>/files/Download` on Android, the sandbox
  ///   Downloads dir on iOS). The user will NOT find it in their Files /
  ///   Downloads app, and it is removed on uninstall. For a user-visible
  ///   save on mobile, use [saveAs].
  /// - **Web**: a browser download (the browser decides the location).
  ///
  /// Existing files are never overwritten — when [fileName] is taken, a
  /// numbered variant is used instead (`report (1).pdf`), matching browser
  /// download behavior. Path separators and other unsafe characters in
  /// [fileName] are sanitized away.
  ///
  /// [mimeType] sets the blob content type on web; native platforms infer
  /// the type from the file extension and ignore it.
  ///
  /// Returns the saved file path (null on web where no path is meaningful).
  Future<PlatformResult<String?>> saveToDevice({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  /// Save a byte stream without user interaction (for large files).
  ///
  /// Same destination rules as [saveToDevice]. On native platforms the
  /// stream is written to disk chunk by chunk (constant memory) via a
  /// temporary `.part` file that only becomes the final file when the
  /// stream completes — a failed stream leaves nothing behind. On web the
  /// stream is buffered into memory before the download triggers — blob
  /// downloads need the full content up front.
  ///
  /// [mimeType] sets the blob content type on web; native platforms infer
  /// the type from the file extension and ignore it.
  ///
  /// Returns the saved file path (null on web).
  Future<PlatformResult<String?>> saveStreamToDevice({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
  });

  /// Save bytes to a location the USER picks via the system dialog.
  ///
  /// This is the user-visible counterpart to [saveToDevice]:
  /// - **Android**: the system create-document dialog — the file lands in
  ///   public storage (Downloads, Drive, …) with no permissions needed.
  /// - **iOS**: the Files export dialog.
  /// - **Desktop**: the native save dialog.
  /// - **Web**: a real save dialog on browsers with the File System Access
  ///   API (Chromium — returns the chosen file name); elsewhere a plain
  ///   browser download (returns null).
  ///
  /// Returns [PlatformCancelled] when the user dismisses the dialog.
  /// Returns the chosen location (platform-dependent form).
  Future<PlatformResult<String?>> saveAs({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
  });
}
