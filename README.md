# device_io

Pick files, share content, save to Downloads, open in external apps. One API across iOS, Android, macOS, Windows, Linux, and web.

## Install

```yaml
dependencies:
  device_io: ^0.0.1
```

## Basic usage

```dart
import 'package:device_io/device_io.dart';

// Initialize (once at app startup)
final deviceIO = await initDeviceIO(downloadSubfolder: 'MyApp');

// Pick an image from the gallery
final result = await deviceIO.assetPicker.pickImage();

// Share a file
await deviceIO.sharing.shareFile(bytes: pdfBytes, fileName: 'report.pdf');

// Save to Downloads
await deviceIO.download.saveToDevice(bytes: csvBytes, fileName: 'export.csv');

// Open in external app
await deviceIO.fileOpener.openFile(filePath: '/path/to/doc.pdf');
```

## Handling results

Every operation returns `PlatformResult` — three possible outcomes:

```dart
final result = await deviceIO.assetPicker.captureImage();

switch (result) {
  case PlatformSupported(:final value):
    // Worked. value is the picked asset (or null if user cancelled).
    if (value != null) useImage(await value.readBytes(), value.mimeType);

  case PlatformUnsupported(:final reason):
    // This platform can't do this (e.g. camera on web).
    showMessage(reason);

  case PlatformFailed(:final message):
    // Platform supports it but something went wrong.
    showError(message);
}
```

No exceptions to catch. Pattern-match and handle each case.

## Picking files

```dart
// Image from gallery
final image = await deviceIO.assetPicker.pickImage(
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 85,
);

// Photo from camera (returns PlatformUnsupported on web/desktop)
final photo = await deviceIO.assetPicker.captureImage();

// Any file type
final file = await deviceIO.assetPicker.pickFile(
  allowedExtensions: ['pdf', 'docx'],
);

// Check if camera is available before showing the button
if (deviceIO.assetPicker.isCameraSupported) {
  showCameraButton();
}
```

Picked assets are lazy — nothing loaded into memory until you ask. Use `readBytes()` for small files or `readStream()` for large files.

## Sharing

```dart
// Share text
await deviceIO.sharing.shareText(text: 'Check this out!', subject: 'Hey');

// Share a file
await deviceIO.sharing.shareFile(
  bytes: imageBytes,
  fileName: 'photo.png',
  mimeType: 'image/png',
);
```

On native, this opens the OS share sheet. On web, it uses the Web Share API (with fallback to `PlatformUnsupported` on browsers that don't support it).

## Saving to Downloads

```dart
// Save bytes
await deviceIO.download.saveToDevice(bytes: data, fileName: 'export.csv');

// Save a stream (large files)
await deviceIO.download.saveStreamToDevice(
  byteStream: largeFileStream,
  fileName: 'backup.zip',
);
```

On native, files go to the Downloads folder (or a subfolder if you set `downloadSubfolder` in `initDeviceIO`). On web, this triggers a browser download.

## Opening in external apps

```dart
await deviceIO.fileOpener.openFile(filePath: '/path/to/file.pdf');
```

Opens the file in the system's default viewer — Preview on macOS, Photos on iOS, etc. On web, opens a blob URL in a new tab.

## Platform support

| Operation | iOS | Android | macOS | Windows | Linux | Web |
|-----------|:---:|:-------:|:-----:|:-------:|:-----:|:---:|
| Pick image (gallery) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Capture (camera) | ✅ | ✅ | — | — | — | — |
| Pick file | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Share text | ✅ | ✅ | ✅ | ✅ | ✅ | Partial |
| Share file | ✅ | ✅ | ✅ | ✅ | ✅ | Partial |
| Save to Downloads | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Open in viewer | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Unsupported operations return `PlatformUnsupported` — never throw.

## Permissions

This package does not request permissions. If an operation needs permission (camera, photo library), grant it in your app first. Missing permission = `PlatformFailed`.

## API overview

**DeviceIO** — container holding all four adapters. Created by `initDeviceIO()`.

**AssetPickerAdapter** — `pickImage`, `captureImage`, `pickFile`, `isCameraSupported`

**SharingAdapter** — `shareText`, `shareFile`

**DownloadAdapter** — `saveToDevice`, `saveStreamToDevice`

**FileOpenerAdapter** — `openFile`

**PlatformResult\<T\>** — sealed type: `PlatformSupported`, `PlatformUnsupported`, `PlatformFailed`

**PickedAsset** — picked file: `readBytes()`, `readStream()`, `mimeType`, `fileName`
