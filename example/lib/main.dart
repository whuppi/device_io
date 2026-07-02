// device_io example — every capability, one file.
//
// ONE file on purpose — pub.dev renders example/lib/main.dart as the
// package's Example tab. Splitting it hides everything past main.dart
// from that page. Do not modularize.
//
// Four tabs, one per API surface:
//   Pick   — assetPicker: gallery images, camera capture, videos,
//            mixed media, generic files. Picked assets are lazy —
//            bytes are read on tap, never at pick time.
//   Share  — sharing: text, single file, multiple files in one
//            sheet, and a ~1MB byte stream.
//   Save   — download: silent save to downloads, streamed save,
//            and the user-picks-destination system dialog.
//   Open   — fileOpener: open in-memory bytes in the default
//            viewer, and open the last silently-saved path.
//
// Every call returns a sealed PlatformResult. One renderer
// (_record) exhaustively switches the family and writes the outcome
// into the activity log — the log sits below the TabBarView, global
// across all tabs. All demo bytes are generated in code; nothing
// touches assets or the network.

import 'dart:convert';
import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // initDeviceIO does platform work (resolving native vs web adapters), so
  // the binding must be ready first.
  WidgetsFlutterBinding.ensureInitialized();
  final deviceIO = await initDeviceIO(
    config: const DeviceIOConfig(downloadSubfolder: 'DeviceIOExample'),
  );
  runApp(DeviceIOExampleApp(deviceIO: deviceIO));
}

class DeviceIOExampleApp extends StatelessWidget {
  const DeviceIOExampleApp({required this.deviceIO, super.key});

  final DeviceIO deviceIO;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'device_io example',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomePage(deviceIO: deviceIO),
    );
  }
}

// ── Activity log model ──────────────────────────────────────────────────

/// Visual severity of a log line, mapped one-to-one onto the five outcomes
/// of [PlatformResult].
enum LogLevel { success, neutral, warning, unsupported, error }

class LogEntry {
  const LogEntry(this.level, this.text);
  final LogLevel level;
  final String text;
}

/// A picked asset plus the byte length lazily read from it. [byteLength] stays
/// null until the user taps the tile — the whole point is to show that
/// [PickedAsset] loads nothing at pick time.
class PickedItem {
  PickedItem(this.asset);
  final PickedAsset asset;
  int? byteLength;
  bool loading = false;
}

class HomePage extends StatefulWidget {
  const HomePage({required this.deviceIO, super.key});

  final DeviceIO deviceIO;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<LogEntry> _log = <LogEntry>[];
  final List<PickedItem> _picked = <PickedItem>[];

  /// Path returned by the most recent [DownloadAdapter.saveToDevice] — feeds
  /// the "open last saved" button. Null on web (no filesystem paths) and
  /// before the first successful save.
  String? _lastSavedPath;

  DeviceIO get _io => widget.deviceIO;

  // ── The pedagogical heart: one exhaustive switch over the sealed family ──

  /// Render any [PlatformResult] into the activity log. Every device_io call
  /// funnels through here, so the five outcomes are handled in exactly one
  /// place. `PlatformPermissionDenied` is matched before its `PlatformFailed`
  /// supertype so the actionable "open settings" hint wins.
  void _record<T>(
    String action,
    PlatformResult<T> result, {
    String Function(T value)? describe,
  }) {
    final entry = switch (result) {
      PlatformSupported<T>(:final value) => LogEntry(
        LogLevel.success,
        describe != null ? '$action → ${describe(value)}' : '$action → ok',
      ),
      PlatformCancelled<T>() => LogEntry(
        LogLevel.neutral,
        '$action → cancelled',
      ),
      PlatformPermissionDenied<T>(:final message) => LogEntry(
        LogLevel.warning,
        '$action → permission denied ($message). Open Settings to grant '
        'access.',
      ),
      PlatformUnsupported<T>(:final reason) => LogEntry(
        LogLevel.unsupported,
        '$action → unsupported: $reason',
      ),
      PlatformFailed<T>(:final message) => LogEntry(
        LogLevel.error,
        '$action → failed: $message',
      ),
    };
    setState(() => _log.insert(0, entry));
  }

  // ── Pick handlers ──────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await _io.assetPicker.pickImage();
    _absorbOne(result);
    _recordAsset(result, action: 'Pick image');
  }

  Future<void> _pickImages() async {
    final result = await _io.assetPicker.pickImages(limit: 10);
    _absorbMany(result);
    _record(
      'Pick images',
      result,
      describe: (assets) => '${assets.length} selected',
    );
  }

  Future<void> _captureImage() async {
    final result = await _io.assetPicker.captureImage();
    _absorbOne(result);
    _recordAsset(result, action: 'Capture image');
  }

  Future<void> _pickVideo() async {
    final result = await _io.assetPicker.pickVideo();
    _absorbOne(result);
    _recordAsset(result, action: 'Pick video');
  }

  Future<void> _captureVideo() async {
    final result = await _io.assetPicker.captureVideo(
      maxDuration: const Duration(seconds: 30),
    );
    _absorbOne(result);
    _recordAsset(result, action: 'Capture video');
  }

  Future<void> _pickMedia() async {
    final result = await _io.assetPicker.pickMedia();
    _absorbOne(result);
    _recordAsset(result, action: 'Pick media');
  }

  Future<void> _pickMultipleMedia() async {
    final result = await _io.assetPicker.pickMultipleMedia(limit: 5);
    _absorbMany(result);
    _record(
      'Pick multiple media',
      result,
      describe: (assets) => '${assets.length} selected',
    );
  }

  Future<void> _pickFile() async {
    final result = await _io.assetPicker.pickFile();
    _absorbOne(result);
    _recordAsset(result, action: 'Pick file');
  }

  Future<void> _pickFiles() async {
    final result = await _io.assetPicker.pickFiles();
    _absorbMany(result);
    _record(
      'Pick files',
      result,
      describe: (assets) => '${assets.length} selected',
    );
  }

  void _absorbOne(PlatformResult<PickedAsset> result) {
    if (result case PlatformSupported(:final value)) {
      setState(() => _picked.add(PickedItem(value)));
    }
  }

  void _absorbMany(PlatformResult<List<PickedAsset>> result) {
    if (result case PlatformSupported(:final value)) {
      setState(() => _picked.addAll(value.map(PickedItem.new)));
    }
  }

  /// Overload-style helper for single-asset picks: logs with the file name.
  void _recordAsset(
    PlatformResult<PickedAsset> result, {
    required String action,
  }) {
    _record(
      action,
      result,
      describe: (asset) => asset.fileName ?? asset.mimeType,
    );
  }

  /// Read bytes on tap — demonstrates that nothing was loaded at pick time.
  Future<void> _measure(PickedItem item) async {
    setState(() => item.loading = true);
    final bytes = await item.asset.readBytes();
    setState(() {
      item.byteLength = bytes.length;
      item.loading = false;
    });
  }

  // ── Share handlers ─────────────────────────────────────────────────────

  Future<void> _shareText() async {
    final result = await _io.sharing.shareText(
      text: 'Shared from the device_io example app.',
      subject: 'device_io',
    );
    _record<void>('Share text', result);
  }

  Future<void> _shareFile() async {
    final bytes = _utf8('Generated in code, shared as a file.\n');
    final result = await _io.sharing.shareFile(
      bytes: bytes,
      fileName: 'note.txt',
      mimeType: 'text/plain',
      text: 'A small text file',
    );
    _record<void>('Share file', result);
  }

  Future<void> _shareFiles() async {
    // sharePositionOrigin omitted: it's the iPadOS popover anchor and null is
    // valid on every other platform. A real app anchors it to the tapped
    // button's global rect on iPad.
    final result = await _io.sharing.shareFiles(
      files: [
        ShareFile(
          bytes: _utf8('name,role\nAlice,admin\nBob,user\n'),
          fileName: 'people.csv',
          mimeType: 'text/csv',
        ),
        ShareFile(
          bytes: _utf8('Two files, one share sheet.\n'),
          fileName: 'note.txt',
          mimeType: 'text/plain',
        ),
      ],
      subject: 'device_io',
      text: 'A CSV and a text file together',
    );
    _record<void>('Share files (CSV + text)', result);
  }

  Future<void> _shareFileStream() async {
    final result = await _io.sharing.shareFileStream(
      byteStream: _patternedStream(1024 * 1024),
      fileName: 'onemb.bin',
      mimeType: 'application/octet-stream',
      text: 'A ~1MB streamed file',
    );
    _record<void>('Share file stream (~1MB)', result);
  }

  // ── Save handlers ──────────────────────────────────────────────────────

  Future<void> _saveToDevice() async {
    final result = await _io.download.saveToDevice(
      bytes: _utf8('name,role\nAlice,admin\nBob,user\n'),
      fileName: 'people.csv',
      mimeType: 'text/csv',
    );
    if (result case PlatformSupported(value: final String? path)) {
      setState(() => _lastSavedPath = path);
    }
    _record('Save CSV', result, describe: _describePath);
  }

  Future<void> _saveStreamToDevice() async {
    final result = await _io.download.saveStreamToDevice(
      byteStream: _textChunkStream(),
      fileName: 'log.txt',
      mimeType: 'text/plain',
    );
    if (result case PlatformSupported(value: final String? path)) {
      setState(() => _lastSavedPath = path);
    }
    _record('Save stream', result, describe: _describePath);
  }

  Future<void> _saveAs() async {
    final result = await _io.download.saveAs(
      bytes: _utf8('id,value\n1,Pick where this lands\n'),
      fileName: 'export.csv',
      dialogTitle: 'Save example export',
      mimeType: 'text/csv',
    );
    _record('Save as…', result, describe: _describePath);
  }

  String _describePath(String? path) => path ?? 'saved (browser download)';

  // ── Open handlers ──────────────────────────────────────────────────────

  Future<void> _openBytes() async {
    final result = await _io.fileOpener.openBytes(
      bytes: _utf8('Opened straight from memory.\n'),
      fileName: 'hello.txt',
      mimeType: 'text/plain',
    );
    _record<void>('Open bytes', result);
  }

  Future<void> _openLastSaved() async {
    final path = _lastSavedPath;
    if (path == null) return;
    final result = await _io.fileOpener.openPath(filePath: path);
    _record<void>('Open last saved', result);
  }

  // ── Generated demo data (no assets, no network) ─────────────────────────

  Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  Stream<List<int>> _patternedStream(int total) async* {
    const chunkSize = 64 * 1024;
    final chunk = List<int>.generate(chunkSize, (i) => i & 0xFF);
    var sent = 0;
    while (sent < total) {
      final remaining = total - sent;
      yield remaining >= chunkSize ? chunk : chunk.sublist(0, remaining);
      sent += chunkSize;
    }
  }

  Stream<List<int>> _textChunkStream() async* {
    for (var i = 1; i <= 5; i++) {
      yield utf8.encode('chunk $i of 5\n');
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('device_io example'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.photo_library_outlined, size: 20),
                text: 'Pick',
              ),
              Tab(
                icon: Icon(Icons.ios_share_outlined, size: 20),
                text: 'Share',
              ),
              Tab(icon: Icon(Icons.download_outlined, size: 20), text: 'Save'),
              Tab(
                icon: Icon(Icons.open_in_new_outlined, size: 20),
                text: 'Open',
              ),
            ],
          ),
        ),
        // The activity log sits BELOW the TabBarView — global, visible on
        // every tab, so a result is never hidden by tab switching.
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [_pickTab(), _shareTab(), _saveTab(), _openTab()],
              ),
            ),
            _ActivityLog(entries: _log),
          ],
        ),
      ),
    );
  }

  Widget _pickTab() {
    final cameraSupported = _io.assetPicker.isCameraSupported;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Pick',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _pickImage,
                  child: const Text('pickImage'),
                ),
                FilledButton.tonal(
                  onPressed: _pickImages,
                  child: const Text('pickImages'),
                ),
                FilledButton.tonal(
                  onPressed: cameraSupported ? _captureImage : null,
                  child: Text(
                    cameraSupported
                        ? 'captureImage'
                        : 'captureImage (no camera)',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _pickVideo,
                  child: const Text('pickVideo'),
                ),
                FilledButton.tonal(
                  onPressed: cameraSupported ? _captureVideo : null,
                  child: Text(
                    cameraSupported
                        ? 'captureVideo'
                        : 'captureVideo (no camera)',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _pickMedia,
                  child: const Text('pickMedia'),
                ),
                FilledButton.tonal(
                  onPressed: _pickMultipleMedia,
                  child: const Text('pickMultipleMedia'),
                ),
                FilledButton.tonal(
                  onPressed: _pickFile,
                  child: const Text('pickFile'),
                ),
                FilledButton.tonal(
                  onPressed: _pickFiles,
                  child: const Text('pickFiles'),
                ),
              ],
            ),
            if (_picked.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Tap a picked asset to read its bytes on demand:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              ..._picked.map(_pickedTile),
            ],
          ],
        ),
      ],
    );
  }

  Widget _shareTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Share',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _shareText,
                  child: const Text('shareText'),
                ),
                FilledButton.tonal(
                  onPressed: _shareFile,
                  child: const Text('shareFile'),
                ),
                FilledButton.tonal(
                  onPressed: _shareFiles,
                  child: const Text('shareFiles (CSV + text)'),
                ),
                FilledButton.tonal(
                  onPressed: _shareFileStream,
                  child: const Text('shareFileStream (~1MB)'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _saveTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Save',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _saveToDevice,
                  child: const Text('saveToDevice (CSV)'),
                ),
                FilledButton.tonal(
                  onPressed: _saveStreamToDevice,
                  child: const Text('saveStreamToDevice'),
                ),
                FilledButton.tonal(
                  onPressed: _saveAs,
                  child: const Text('saveAs'),
                ),
              ],
            ),
            if (_lastSavedPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last saved: $_lastSavedPath',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _openTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Open',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _openBytes,
                  child: const Text('openBytes'),
                ),
                FilledButton.tonal(
                  onPressed: _lastSavedPath != null ? _openLastSaved : null,
                  child: const Text('openPath (last saved)'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _pickedTile(PickedItem item) {
    final subtitle = StringBuffer(item.asset.mimeType);
    if (item.loading) {
      subtitle.write(' • reading…');
    } else if (item.byteLength != null) {
      subtitle.write(' • ${item.byteLength} bytes');
    } else {
      subtitle.write(' • tap to read bytes');
    }
    return ListTile(
      dense: true,
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text(item.asset.fileName ?? '(no name)'),
      subtitle: Text(subtitle.toString()),
      onTap: item.loading ? null : () => _measure(item),
    );
  }
}

// ── Presentational widgets ──────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActivityLog extends StatelessWidget {
  const _ActivityLog({required this.entries});

  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Container(
        height: 180,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Activity',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('No activity yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (context, i) => _logRow(entries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logRow(LogEntry entry) {
    final (color, icon) = switch (entry.level) {
      LogLevel.success => (Colors.green, Icons.check_circle_outline),
      LogLevel.neutral => (Colors.blueGrey, Icons.remove_circle_outline),
      LogLevel.warning => (Colors.amber.shade800, Icons.warning_amber_outlined),
      LogLevel.unsupported => (Colors.grey, Icons.block_outlined),
      LogLevel.error => (Colors.red, Icons.error_outline),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(entry.text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
