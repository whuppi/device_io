import 'package:device_io/src/links/link_budget.dart';
import 'package:device_io/src/types/outcome.dart';

/// The linked file is gone — moved, deleted, or its bookmark no longer
/// resolves. Relinking is the recovery.
final class LinkTargetMissing<T> extends Failed<T> {
  /// Creates the failure.
  const LinkTargetMissing({
    String message = 'The linked file is no longer there',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  @override
  String toString() => 'LinkTargetMissing($message)';
}

/// The linked file exists but its bytes are not on this device — an
/// iCloud placeholder. [startDownload] asks the system to fetch it; open
/// again once it is here.
final class LinkNotDownloaded<T> extends Failed<T> {
  /// Creates the failure.
  const LinkNotDownloaded({
    required this.startDownload,
    String message = 'The linked file is not downloaded to this device',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  /// Begins the download. Resolves when the request was accepted, not
  /// when the bytes have arrived.
  final Future<void> Function() startDownload;

  @override
  String toString() => 'LinkNotDownloaded($message)';
}

/// The access the link relied on is gone — the grant was released by the
/// system or the person, or the scope refused. Relinking is the recovery.
final class LinkPermissionGone<T> extends Failed<T> {
  /// Creates the failure.
  const LinkPermissionGone({
    String message = 'Access to the linked file was revoked',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  @override
  String toString() => 'LinkPermissionGone($message)';
}

/// The platform's grant budget is at its reserve. Unlink something, or
/// link the folder instead — one grant for every file in it.
final class LinkBudgetFull<T> extends Failed<T> {
  /// Creates the failure.
  const LinkBudgetFull({
    required this.budget,
    String message = 'No room for another linked file on this device',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  /// The budget at the moment of refusal.
  final LinkBudget budget;

  @override
  String toString() => 'LinkBudgetFull($budget)';
}

/// The copy path could not read a candidate: `LinkCandidate.readStream`
/// fails with this when the platform refuses the read. [refusal] is the
/// same typed answer `FileLinks.open` would have given — switch on it.
final class LinkReadError implements Exception {
  /// Creates the error around the platform's refusal.
  const LinkReadError(this.refusal);

  /// Why the read was refused: [LinkTargetMissing], [LinkNotDownloaded],
  /// [LinkPermissionGone], or a plain [Failed].
  final Failed<void> refusal;

  @override
  String toString() => 'LinkReadError(${refusal.message})';
}

/// Linking was asked of a candidate whose strength is not durable. Read
/// it through `LinkCandidate.readStream` and copy instead.
final class LinkNotDurable<T> extends Failed<T> {
  /// Creates the failure.
  const LinkNotDurable({
    String message = 'This file cannot be linked in place',
    Object? error,
    StackTrace? stackTrace,
  }) : super(message, error: error, stackTrace: stackTrace);

  @override
  String toString() => 'LinkNotDurable($message)';
}
