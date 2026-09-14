import 'package:meta/meta.dart';

/// How many durable links this platform lets the app hold.
///
/// Android persists at most 128 content grants per app (512 from
/// Android 11); the other platforms count nothing. `FileLinks.link`
/// refuses at [capacity] minus a reserve instead of letting the OS throw
/// at the wall.
@immutable
final class LinkBudget {
  /// Creates a budget.
  const LinkBudget({required this.used, required this.capacity});

  /// A platform that never counts.
  const LinkBudget.uncounted() : used = 0, capacity = null;

  /// Grants currently held.
  final int used;

  /// The platform's cap, or null where nothing is counted.
  final int? capacity;

  /// Grants kept free so a folder link is always still possible when the
  /// per-file count runs high.
  static const int reserve = 8;

  /// Whether one more per-file link is allowed.
  bool get canLink {
    final cap = capacity;
    return cap == null || used < cap - reserve;
  }

  @override
  bool operator ==(Object other) =>
      other is LinkBudget && other.used == used && other.capacity == capacity;

  @override
  int get hashCode => Object.hash(used, capacity);

  @override
  String toString() => 'LinkBudget($used of ${capacity ?? '∞'})';
}
