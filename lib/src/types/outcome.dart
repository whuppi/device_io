import 'package:meta/meta.dart';

/// Result of a platform IO operation that may not be supported on all
/// platforms.
///
/// Five outcomes:
/// - [Success] — operation succeeded with a value
/// - [Cancelled] — the user dismissed the picker / share sheet
/// - [Unsupported] — operation is not available on this platform
/// - [Failed] — operation is supported but failed at runtime
///   (with [PermissionDenied] as the named permission failure)
///
/// Pattern-match with a `switch` for exhaustive handling. There are no
/// helper getters on purpose — a sealed result consumed through escape
/// hatches stops being exhaustive.
///
/// ```dart
/// final result = await deviceIO.picker.pickImage();
/// switch (result) {
///   case Success(:final value): use(value);
///   case Cancelled(): break; // user changed their mind
///   case PermissionDenied(): promptForSettings();
///   case Unsupported(:final reason): hideFeature(reason);
///   case Failed(:final message): showError(message);
/// }
/// ```
@immutable
sealed class Outcome<T> {
  /// Const base constructor for the sealed subclasses.
  const Outcome();
}

/// Operation succeeded with a value.
final class Success<T> extends Outcome<T> {
  /// Creates a success result carrying [value].
  const Success(this.value);

  /// The operation's result value.
  final T value;

  @override
  String toString() => 'Success($value)';
}

/// The user cancelled the operation — dismissed the picker, the camera,
/// or the share sheet. A normal outcome, not an error.
final class Cancelled<T> extends Outcome<T> {
  /// Creates a cancelled result.
  const Cancelled();

  @override
  String toString() => 'Cancelled()';
}

/// Operation is not supported on this platform.
final class Unsupported<T> extends Outcome<T> {
  /// Creates an unsupported result explaining why in [reason].
  const Unsupported(this.reason);

  /// Human-readable explanation of why the operation is unavailable.
  final String reason;

  @override
  String toString() => 'Unsupported($reason)';
}

/// Operation is supported but failed at runtime.
///
/// Subtypes name the failures consumers branch on — currently
/// [PermissionDenied]. A plain `case Failed()` arm matches
/// the subtypes too, so generic handling stays a single arm; when a switch
/// has BOTH arms, the [PermissionDenied] arm must come first.
class Failed<T> extends Outcome<T> {
  /// Creates a failure result with a [message], and the caught [error]
  /// plus its [stackTrace] when available.
  const Failed(this.message, {this.error, this.stackTrace});

  /// Human-readable description of the failure (diagnostic, not localized —
  /// apps translate for their users).
  final String message;

  /// The underlying error, when one was caught.
  final Object? error;

  /// The stack trace captured with [error], for diagnostics and reporting.
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failed($message)';
}

/// The OS denied a required permission (camera, photo library, storage).
///
/// The one failure worth branching on: the recovery is prompting the user
/// toward system settings, not retrying.
final class PermissionDenied<T> extends Failed<T> {
  /// Creates a permission-denied failure.
  const PermissionDenied({
    String message = 'Permission denied',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  @override
  String toString() => 'PermissionDenied($message)';
}
