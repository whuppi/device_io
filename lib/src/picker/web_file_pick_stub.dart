import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/outcome.dart';

/// Lazy web file pick — not applicable off web.
///
/// Returns null so the caller falls through to the file_picker path. Only
/// the web implementation (`web_file_pick_web.dart`) does real work; this
/// stub is the default export so pana attributes the package to every
/// platform.
Future<Outcome<List<PickedAsset>>?> lazyWebFilePick({
  required bool allowMultiple,
  List<String>? allowedExtensions,
}) => Future<Outcome<List<PickedAsset>>?>.value(null);
