import 'package:device_io/device_io.dart';
import 'package:test/test.dart';

void main() {
  group('LinkBudget', () {
    test('an uncounted platform always allows another link', () {
      const budget = LinkBudget.uncounted();
      expect(budget.capacity, isNull);
      expect(budget.canLink, isTrue);
    });

    test('refuses at the reserve, not at the wall', () {
      expect(const LinkBudget(used: 0, capacity: 128).canLink, isTrue);
      expect(
        const LinkBudget(
          used: 128 - LinkBudget.reserve - 1,
          capacity: 128,
        ).canLink,
        isTrue,
      );
      expect(
        const LinkBudget(used: 128 - LinkBudget.reserve, capacity: 128).canLink,
        isFalse,
      );
      expect(const LinkBudget(used: 511, capacity: 512).canLink, isFalse);
    });

    test('is a value', () {
      expect(
        const LinkBudget(used: 3, capacity: 512),
        equals(const LinkBudget(used: 3, capacity: 512)),
      );
      expect(
        const LinkBudget(used: 3, capacity: 512).toString(),
        'LinkBudget(3 of 512)',
      );
      expect(const LinkBudget.uncounted().toString(), 'LinkBudget(0 of ∞)');
    });
  });
}
