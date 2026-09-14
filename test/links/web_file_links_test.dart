import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/web/file_links.dart';
import 'package:test/test.dart';

final class _Picker implements AssetPicker {
  _Picker(this.outcome);
  final Outcome<List<PickedAsset>> outcome;
  List<String>? extensions;

  @override
  Future<Outcome<List<PickedAsset>>> pickFiles({
    List<String>? allowedExtensions,
  }) async {
    extensions = allowedExtensions;
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('only pickFiles is exercised');
}

void main() {
  test('every picked blob is readable now and linkable never', () async {
    final asset = PickedAsset.fromBytes(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'application/octet-stream',
      fileName: 'q.gguf',
    );
    final picker = _Picker(Success([asset]));
    final links = WebFileLinks(picker: picker);

    final picked = await links.pickFiles(allowedExtensions: ['gguf']);
    expect(picker.extensions, ['gguf']);
    final candidate = (picked as Success<List<LinkCandidate>>).value.single;
    expect(candidate.strength, LinkStrength.none);
    expect(candidate.reason, isNotNull);
    expect(await candidate.readBytes(), [1, 2, 3]);

    expect(await links.link(candidate), isA<LinkNotDurable<FileRef>>());
    expect(await links.pickFolder(), isA<Unsupported<FolderRef>>());
    expect(
      await links.candidateForPath('/x'),
      isA<Unsupported<LinkCandidate>>(),
    );
    expect(
      await links.open(FileRef.restore(token: 'x', displayName: 'x')),
      isA<Unsupported<FileHandle>>(),
    );
    expect(await links.budget(), const LinkBudget.uncounted());
  });

  test('the picker\'s own outcomes pass through', () async {
    expect(
      await WebFileLinks(picker: _Picker(const Cancelled())).pickFiles(),
      isA<Cancelled<List<LinkCandidate>>>(),
    );
    expect(
      await WebFileLinks(picker: _Picker(const PermissionDenied())).pickFiles(),
      isA<PermissionDenied<List<LinkCandidate>>>(),
    );
  });
}
