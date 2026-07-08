// Fake ImagePickerPlatform for the picker adapter suite. Installed via
// `ImagePickerPlatform.instance = fake` — the MockPlatformInterfaceMixin
// disables the plugin-interface token check so a test double is accepted.
//
// This fake RECORDS the option arguments the adapter routes to each platform
// method (getImageFromSource / getMultiImageWithOptions / getMedia / getVideo)
// and returns SCRIPTED XFiles / empty lists / thrown errors. Tests assert both the
// recorded request AND the mapped result, so a gutted adapter that dropped an
// option or mis-routed a source is caught.
//
// io-exempt: TempWorkspace writes real temp files so the XFiles this fake
// hands back are file-backed — the adapter's lazy readBytes reads the
// DECLARED bytes off disk, proving the asset is wired to the pick.

import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Which platform method the adapter's call routed to. Recorded so a
/// mis-route (e.g. captureImage reaching getMedia) fails a test.
enum PickerRoute {
  getImageFromSource,
  getMultiImageWithOptions,
  getMedia,
  getVideo,
}

/// A recording, scripting fake of [ImagePickerPlatform].
final class FakeImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  // ── recorded request ──
  bool called = false;
  PickerRoute? route;
  ImageSource? source;
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;
  int? limit;
  bool? allowMultiple;
  Duration? maxDuration;

  // ── script ──
  /// Returned by [getImageFromSource] and [getVideo].
  XFile? single;

  /// Returned by [getMultiImageWithOptions] and [getMedia].
  List<XFile> multi = const [];

  /// When set, every routed method throws this instead of returning.
  Object? error;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    called = true;
    route = PickerRoute.getImageFromSource;
    this.source = source;
    maxWidth = options.maxWidth;
    maxHeight = options.maxHeight;
    imageQuality = options.imageQuality;
    if (error != null) throw error!;
    return single;
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    called = true;
    route = PickerRoute.getMultiImageWithOptions;
    maxWidth = options.imageOptions.maxWidth;
    maxHeight = options.imageOptions.maxHeight;
    imageQuality = options.imageOptions.imageQuality;
    limit = options.limit;
    if (error != null) throw error!;
    return multi;
  }

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    called = true;
    route = PickerRoute.getMedia;
    maxWidth = options.imageOptions.maxWidth;
    maxHeight = options.imageOptions.maxHeight;
    imageQuality = options.imageOptions.imageQuality;
    allowMultiple = options.allowMultiple;
    limit = options.limit;
    if (error != null) throw error!;
    return multi;
  }

  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    called = true;
    route = PickerRoute.getVideo;
    this.source = source;
    this.maxDuration = maxDuration;
    if (error != null) throw error!;
    return single;
  }
}

/// Creates real temp files whose bytes the test declares, so an XFile (or a
/// file_picker PlatformFile path) hands back the exact declared bytes when
/// the adapter's lazy read runs. Call [dispose] in tearDown.
final class TempWorkspace {
  TempWorkspace()
    : _dir = Directory.systemTemp.createTempSync('device_io_picker_test_');

  final Directory _dir;
  var _seq = 0;

  /// Writes [bytes] to a file named exactly [fileName] in a fresh per-file
  /// subdirectory (so the path's basename IS [fileName] — cross_file's io
  /// `XFile.name` reads the path basename, not any constructor name) and
  /// returns its path. Join with [Platform.pathSeparator], never a literal
  /// `/`: cross_file splits the basename on the platform separator, so on
  /// Windows (`\`) a `/`-joined subpath stays glued to the name and the
  /// pick's fileName comes back as the whole relative path.
  String writeFile(String fileName, Uint8List bytes) {
    final sep = Platform.pathSeparator;
    final sub = Directory('${_dir.path}$sep${_seq++}')..createSync();
    final file = File('${sub.path}$sep$fileName')..writeAsBytesSync(bytes);
    return file.path;
  }

  /// A file-backed [XFile] over declared [bytes]. [mimeType] is left null
  /// unless given, so the adapter's fileName-based inference is exercised.
  XFile xFile(String fileName, Uint8List bytes, {String? mimeType}) {
    return XFile(
      writeFile(fileName, bytes),
      name: fileName,
      mimeType: mimeType,
    );
  }

  void dispose() {
    if (_dir.existsSync()) _dir.deleteSync(recursive: true);
  }
}
