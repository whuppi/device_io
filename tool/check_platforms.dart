// Gate pub.dev platform support. Reads pana's JSON report from stdin and
// fails unless all six platform tags are present — the regression this
// catches is an unconditional dart:io / package:web import reaching the
// shared surface and silently dropping platforms from the pub.dev score.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final input = await stdin.transform(utf8.decoder).join();
  final report = jsonDecode(input) as Map<String, dynamic>;
  final tags = (report['tags'] as List?)?.cast<String>() ?? const <String>[];

  const expected = [
    'platform:android',
    'platform:ios',
    'platform:macos',
    'platform:linux',
    'platform:windows',
    'platform:web',
  ];
  final missing = expected.where((tag) => !tags.contains(tag)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('✗ pub.dev platform support regressed — missing: $missing');
    exit(1);
  }
  stdout.writeln('✓ pana reports all six platforms');
}
