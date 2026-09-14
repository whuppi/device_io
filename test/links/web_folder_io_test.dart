import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/web/folder_io.dart';
import 'package:test/test.dart';

void main() {
  test('every method is Unsupported — browsers keep no folder grant', () async {
    const folders = WebFolderIo();
    final folder = FolderRef.restore(token: 'x', displayName: 'x');

    expect(await folders.read(folder, 'a.txt'), isA<Unsupported<Uint8List?>>());
    expect(
      await folders.write(folder, 'a.txt', Uint8List(0)),
      isA<Unsupported<void>>(),
    );
    expect(await folders.list(folder, ''), isA<Unsupported<List<String>>>());
    expect(await folders.delete(folder, 'a.txt'), isA<Unsupported<void>>());
  });
}
