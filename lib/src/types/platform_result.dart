/// Result of a platform IO operation that may not be supported on all
/// platforms.
///
/// Four outcomes:
/// - [PlatformSupported] — operation succeeded with a value
/// - [PlatformCancelled] — the user dismissed the picker / share sheet
/// - [PlatformUnsupported] — operation is not available on this platform
/// - [PlatformFailed] — operation is supported but failed at runtime
///   (with [PlatformPermissionDenied] as the named permission failure)
///
/// Pattern-match with a `switch` for exhaustive handling, or use [when]:
///
/// ```dart
/// final result = await deviceIO.assetPicker.pickImage();
/// switch (result) {
///   case PlatformSupported(:final value): use(value);
///   case PlatformCancelled(): break; // user changed their mind
///   case PlatformUnsupported(:final reason): hideFeature(reason);
///   case PlatformPermissionDenied(): promptForSettings();
///   case PlatformFailed(:final message): showError(message);
/// }
/// ```
sealed class PlatformResult<T> {
  /// Const base constructor for the sealed subclasses.
  const PlatformResult();

  /// True if this is a [PlatformSupported] result.
  bool get isSupported => this is PlatformSupported<T>;

  /// True if this is a [PlatformCancelled] result.
  bool get isCancelled => this is PlatformCancelled<T>;

  /// True if this is a [PlatformUnsupported] result.
  bool get isUnsupported => this is PlatformUnsupported<T>;

  /// True if this is a [PlatformFailed] result.
  bool get isFailed => this is PlatformFailed<T>;

  /// Gets the value if supported, or null otherwise.
  T? get valueOrNull => switch (this) {
    PlatformSupported(:final value) => value,
    _ => null,
  };

  /// Execute a callback based on the result type.
  ///
  /// [PlatformPermissionDenied] routes to [failed] — pattern-match with a
  /// `switch` when it needs distinct handling.
  R when<R>({
    required R Function(T value) supported,
    required R Function() cancelled,
    required R Function(String reason) unsupported,
    required R Function(String message, Object? error) failed,
  }) {
    return switch (this) {
      PlatformSupported(:final value) => supported(value),
      PlatformCancelled() => cancelled(),
      PlatformUnsupported(:final reason) => unsupported(reason),
      PlatformFailed(:final message, :final error) => failed(message, error),
    };
  }

  /// Map the success value. Every other variant passes through unchanged.
  PlatformResult<U> map<U>(U Function(T) transform) {
    return switch (this) {
      PlatformSupported(:final value) => PlatformSupported(transform(value)),
      PlatformCancelled() => PlatformCancelled<U>(),
      PlatformUnsupported(:final reason) => PlatformUnsupported(reason),
      PlatformPermissionDenied(:final message, :final error) =>
        PlatformPermissionDenied<U>(message: message, error: error),
      PlatformFailed(:final message, :final error) => PlatformFailed(
        message,
        error: error,
      ),
    };
  }
}

/// Operation succeeded with a value.
final class PlatformSupported<T> extends PlatformResult<T> {
  /// Creates a success result carrying [value].
  const PlatformSupported(this.value);

  /// The operation's result value.
  final T value;

  @override
  String toString() => 'PlatformSupported($value)';
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
/// [PlatformPermissionDenied]. A plain `case PlatformFailed()` arm
/// matches the subtypes too, so generic handling stays a single arm.
class PlatformFailed<T> extends PlatformResult<T> {
  /// Creates a failure result with a [message] and optional [error] cause.
  const PlatformFailed(this.message, {this.error});

  /// Human-readable description of the failure.
  final String message;

  /// The underlying error, when one was caught.
  final Object? error;

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
  }) : super(message, error: error);

  @override
  String toString() => 'PlatformPermissionDenied($message)';
}
