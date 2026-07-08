import 'package:meta/meta.dart';

/// Result of a platform IO operation that may not be supported on all
/// platforms.
///
/// Five outcomes:
/// - [PlatformSuccess] — operation succeeded with a value
/// - [PlatformCancelled] — the user dismissed the picker / share sheet
/// - [PlatformUnsupported] — operation is not available on this platform
/// - [PlatformFailed] — operation is supported but failed at runtime
///   (with [PlatformPermissionDenied] as the named permission failure)
///
/// Pattern-match with a `switch` for exhaustive handling. There are no
/// helper getters on purpose — a sealed result consumed through escape
/// hatches stops being exhaustive.
///
/// ```dart
/// final result = await deviceIO.picker.pickImage();
/// switch (result) {
///   case PlatformSuccess(:final value): use(value);
///   case PlatformCancelled(): break; // user changed their mind
///   case PlatformPermissionDenied(): promptForSettings();
///   case PlatformUnsupported(:final reason): hideFeature(reason);
///   case PlatformFailed(:final message): showError(message);
/// }
/// ```
@immutable
sealed class PlatformResult<T> {
  /// Const base constructor for the sealed subclasses.
  const PlatformResult();
}

/// Operation succeeded with a value.
final class PlatformSuccess<T> extends PlatformResult<T> {
  /// Creates a success result carrying [value].
  const PlatformSuccess(this.value);

  /// The operation's result value.
  final T value;

  @override
  String toString() => 'PlatformSuccess($value)';
}

/// The user cancelled the operation — dismissed the picker, the camera,
/// or the share sheet. A normal outcome, not an error.
final class PlatformCancelled<T> extends PlatformResult<T> {
  /// Creates a cancelled result.
  const PlatformCancelled();

  @override
  String toString() => 'PlatformCancelled()';
}

/// Operation is not supported on this platform.
final class PlatformUnsupported<T> extends PlatformResult<T> {
  /// Creates an unsupported result explaining why in [reason].
  const PlatformUnsupported(this.reason);

  /// Human-readable explanation of why the operation is unavailable.
  final String reason;

  @override
  String toString() => 'PlatformUnsupported($reason)';
}

/// Operation is supported but failed at runtime.
///
/// Subtypes name the failures consumers branch on — currently
/// [PlatformPermissionDenied]. A plain `case PlatformFailed()` arm matches
/// the subtypes too, so generic handling stays a single arm; when a switch
/// has BOTH arms, the [PlatformPermissionDenied] arm must come first.
class PlatformFailed<T> extends PlatformResult<T> {
  /// Creates a failure result with a [message], and the caught [error]
  /// plus its [stackTrace] when available.
  const PlatformFailed(this.message, {this.error, this.stackTrace});

  /// Human-readable description of the failure (diagnostic, not localized —
  /// apps translate for their users).
  final String message;

  /// The underlying error, when one was caught.
  final Object? error;

  /// The stack trace captured with [error], for diagnostics and reporting.
  final StackTrace? stackTrace;

  @override
  String toString() => 'PlatformFailed($message)';
}

/// The OS denied a required permission (camera, photo library, storage).
///
/// The one failure worth branching on: the recovery is prompting the user
/// toward system settings, not retrying.
final class PlatformPermissionDenied<T> extends PlatformFailed<T> {
  /// Creates a permission-denied failure.
  const PlatformPermissionDenied({
    String message = 'Permission denied',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  @override
  String toString() => 'PlatformPermissionDenied($message)';
}
