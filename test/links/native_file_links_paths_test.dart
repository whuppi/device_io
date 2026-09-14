// The paths world of NativeFileLinks — Linux and Windows, where no native
// half is registered: file_picker hands out paths, a path is its own
// durable link, and a handle is the path itself.
//
// io-exempt: this world IS dart:io — the subject links and opens real
// temp files.
import 'dart:io';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/native/file_links.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fake_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFilePicker picker;
  late Directory dir;
  late NativeFileLinks links;

  setUp(() {
    picker = FakeFilePicker()..install();
    dir = Directory.systemTemp.createTempSync('device_io_links');
    // No plugin registered for the links channel → MissingPluginException
    // → the paths world.
    links = NativeFileLinks();
  });
  tearDown(() {
    picker.uninstall();
    dir.deleteSync(recursive: true);
  });

  File write(String name, String body) =>
      File('${dir.path}/$name')..writeAsStringSync(body);

  test(
    'a picked path is durable, links to itself, and opens by path',
    () async {
      final file = write('q.gguf', 'weights');
      picker.returnFiles([
        {'name': 'q.gguf', 'path': file.path, 'size': 7},
      ]);
      final picked = await links.pickFiles(allowedExtensions: ['gguf']);
      expect(picker.allowedExtensions, ['gguf']);
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      expect(candidate.strength, LinkStrength.durable);
      expect(await candidate.readBytes(), 'weights'.codeUnits);

      final ref = ((await links.link(candidate)) as Success<FileRef>).value;
      expect(ref.token, 'path:${file.path}');

      final handle = ((await links.open(ref)) as Success<FileHandle>).value;
      expect(handle, isA<FilePathHandle>());
      expect((handle as FilePathHandle).path, file.path);
      expect(handle.sizeBytes, 7);
      await handle.close();
      expect(await links.budget(), const LinkBudget.uncounted());
    },
  );

  test('a moved file is LinkTargetMissing, not a crash', () async {
    final ref = FileRef.restore(
      token: 'path:${dir.path}/gone.gguf',
      displayName: 'gone.gguf',
    );
    expect(await links.open(ref), isA<LinkTargetMissing<FileHandle>>());
  });

  test(
    'a picked folder lists its files, filtered, sorted, non-recursive',
    () async {
      write('b.gguf', 'b');
      write('a.gguf', 'a');
      write('notes.txt', 'n');
      Directory('${dir.path}/sub').createSync();
      write('sub/c.gguf', 'c');
      picker.returnDirectory(dir.path);

      final folder = ((await links.pickFolder()) as Success<FolderRef>).value;
      expect(folder.token, 'path:${dir.path}');
      final kids =
          ((await links.children(folder, allowedExtensions: ['gguf']))
                  as Success<List<LinkCandidate>>)
              .value;
      expect(kids.map((k) => k.displayName), ['a.gguf', 'b.gguf']);
      expect(kids.map((k) => k.relativeDirectory), ['', '']);
      expect(await links.unlinkFolder(folder), isA<Success<void>>());
    },
  );

  test('a recursive listing carries each file\'s directory', () async {
    write('top.gguf', 't');
    Directory('${dir.path}/gemma/q4').createSync(recursive: true);
    write('gemma/q4/weights.gguf', 'w');
    write('gemma/q4/mmproj.gguf', 'p');
    picker.returnDirectory(dir.path);

    final folder = ((await links.pickFolder()) as Success<FolderRef>).value;
    final kids =
        ((await links.children(
                  folder,
                  allowedExtensions: ['gguf'],
                  recursive: true,
                ))
                as Success<List<LinkCandidate>>)
            .value;
    expect(kids.map((k) => k.displayName), [
      'mmproj.gguf',
      'top.gguf',
      'weights.gguf',
    ]);
    expect(kids.map((k) => k.relativeDirectory), ['gemma/q4', '', 'gemma/q4']);
  });

  test('a cancelled pick is Cancelled', () async {
    picker.returnCancelled();
    expect(await links.pickFiles(), isA<Cancelled<List<LinkCandidate>>>());
    picker.returnDirectory(null);
    expect(await links.pickFolder(), isA<Cancelled<FolderRef>>());
  });
}
