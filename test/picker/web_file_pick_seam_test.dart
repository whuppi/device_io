// CHARTER — this file alone proves: on the VM, the `lazyWebFilePick` platform
// seam (the stub-default conditional export in web_file_pick.dart) resolves to
// the STUB and returns null for every combination — single and multiple, with
// and without an extension filter. Null is the signal that means "the File
// System Access path doesn't apply here"; it is what makes a native file pick
// always fall through to the file_picker path in the adapter. This is the VM
// side of the platform seam; the web side lives in test/web_runners.
// Diet: inline literals declared in this file.

import 'package:device_io/src/picker/web_file_pick.dart';
import 'package:test/test.dart';

import '../harness/timeouts.dart';

void main() {
  // Declared truth: off web, the seam always defers with null.
  const kExtensions = ['png', 'jpg'];

  test('single, no extensions → null (stub defers)', () async {
    final result = await lazyWebFilePick(allowMultiple: false);
    expect(result, isNull);
  }, timeout: t(2));

  test('multiple, no extensions → null (stub defers)', () async {
    final result = await lazyWebFilePick(allowMultiple: true);
    expect(result, isNull);
  }, timeout: t(2));

  test('single, with extensions → null (stub defers)', () async {
    final result = await lazyWebFilePick(
      allowMultiple: false,
      allowedExtensions: kExtensions,
    );
    expect(result, isNull);
  }, timeout: t(2));

  test('multiple, with extensions → null (stub defers)', () async {
    final result = await lazyWebFilePick(
      allowMultiple: true,
      allowedExtensions: kExtensions,
    );
    expect(result, isNull);
  }, timeout: t(2));
}
