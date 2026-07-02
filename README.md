<!--
  Banner is commented out until the assets exist. Drop
  assets/banner_dark-web-min.webp + assets/banner_light-web-min.webp in,
  then uncomment. Kept out of the render so there's no broken image in the
  meantime. Note for whoever adds it: pub.dev strips <picture> when it
  sanitizes the README, so the published copy needs the inner <img>
  flattened out (the repo copy can keep <picture> for GitHub dark/light).

  <p align="center">
    <picture>
      <source media="(prefers-color-scheme: dark)"  srcset="assets/banner_dark-web-min.webp">
      <source media="(prefers-color-scheme: light)" srcset="assets/banner_light-web-min.webp">
      <img alt="device_io — cross-platform device IO for Flutter"
           src="assets/banner_light-web-min.webp" width="100%">
    </picture>
  </p>
-->

<p align="center">
  <a href="https://pub.dev/packages/device_io"><img src="https://img.shields.io/pub/v/device_io.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/device_io/score"><img src="https://img.shields.io/pub/likes/device_io" alt="likes"></a>
  <a href="https://pub.dev/packages/device_io/score"><img src="https://img.shields.io/pub/points/device_io" alt="pub points"></a>
  <a href="https://github.com/whuppi/device_io"><img src="https://img.shields.io/github/stars/whuppi/device_io?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

Pick images and files, share through the OS sheet, save to the device, open in the default viewer. One API on iOS, Android, macOS, Windows, Linux, and web. Every operation returns a typed result instead of throwing, so a cancelled picker, an unsupported platform, and a real failure are distinct values your `switch` handles — no `kIsWeb` in your app code, ever. Reads are lazy: a 2GB video from the gallery never lands in memory unless you ask for its bytes.

> like it? a [⭐ star](https://github.com/whuppi/device_io) or [👍 like](https://pub.dev/packages/device_io) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/device_io/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
  - [Add the dependency](#add-the-dependency)
  - [iOS](#ios)
  - [Android](#android)
  - [macOS](#macos)
  - [Linux, Windows, Web](#linux-windows-web)
- [Quick start](#quick-start)
- [Results](#results)
- [Usage](#usage)
  - [Pick](#pick)
  - [Share](#share)
  - [Save](#save)
  - [Open](#open)
- [Error handling](#error-handling)
- [Platform support](#platform-support)
  - [Where saves land](#where-saves-land)
  - [Browser support](#browser-support)
- [Not in the box](#not-in-the-box)
- [Docs](#docs)

</details>

---

## Install

### Add the dependency

```yaml
dependencies:
  device_io:
```

Then call `initDeviceIO()` once at startup and hold onto the result (see [Quick start](#quick-start)). The picker, share, save, and open plugins underneath are federated across all six platforms, so there's no per-platform Dart to wire up. What each platform *does* need is the permission and entitlement declarations below — the OS requires them, and no package can add them to your app for you.

### iOS

Add the usage descriptions your app actually triggers to `ios/Runner/Info.plist`. Write your own copy — the OS shows these strings to the user in the permission prompt:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Lets you pick photos to attach and share.</string>
<key>NSCameraUsageDescription</key>
<string>Lets you capture a photo or video from the camera.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used while recording video from the camera.</string>
```

Skip the keys for features you don't use — no camera capture means no `NSCameraUsageDescription`.

### Android

No manifest permissions. Picking goes through the Android photo picker and the Storage Access Framework, and `saveAs` writes through the system create-document dialog — none of those need a runtime permission or a `<uses-permission>` line.

One thing to check: `device_io` depends on `share_plus` 12, which sets Android build-tool floors. Your `android/` project needs **AGP ≥ 8.12.1**, **Gradle ≥ 8.13**, and **Kotlin 2.2.0**. If your app was scaffolded a while ago, bump those in `settings.gradle` / the Gradle wrapper before the first build.

### macOS

The App Sandbox gates file access behind entitlements. Add these to **both** `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<!-- saveAs + file picking — locations the user chooses in a dialog -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<!-- silent saveToDevice into the real Downloads folder -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

Skip the Downloads entitlement if you only ever use `saveAs`; a silent `saveToDevice` returns `PlatformFailed` without it.

### Linux, Windows, Web

Nothing to add. They work as soon as the dependency resolves.

---

## Quick start

Initialize once, then reach for the four capabilities off the returned container. Here's pick-an-image-then-share-it, the whole round trip:

```dart
import 'package:device_io/device_io.dart';

// once, at app startup — keep the instance around
final deviceIO = await initDeviceIO(
  config: DeviceIOConfig(downloadSubfolder: 'MyApp'),
);

// pick, then share the bytes
final picked = await deviceIO.assetPicker.pickImage();
if (picked case PlatformSupported(value: final asset)) {
  await deviceIO.sharing.shareFile(
    bytes: await asset.readBytes(),
    fileName: asset.fileName ?? 'photo.png',
    text: 'Look at this!',
  );
}
```

That's the shape of every call: ask a capability, get a `PlatformResult`, match the outcome you care about. `pickImage`, `shareFile`, `saveToDevice`, `openBytes` — same shape, a different verb. The `if (... case ...)` above handles just the happy path; when you want to react to every outcome, `switch` over the sealed result and let the compiler check you covered each arm:

```dart
final result = await deviceIO.assetPicker.pickImage();
switch (result) {
  case PlatformSupported(:final value):
    await upload(await value.readBytes());
  case PlatformCancelled():
    break; // user changed their mind — not an error
  case PlatformPermissionDenied():
    promptForSettings();
  case PlatformUnsupported(:final reason):
    hideFeature(reason);
  case PlatformFailed(:final message):
    showError(message);
}
```

---

## Results

Every method returns a `PlatformResult<T>`. Five outcomes, each a distinct value:

| Variant | Means | Typical handling |
|---|---|---|
| `PlatformSupported(value)` | It worked; `value` is the payload | Use it |
| `PlatformCancelled()` | User dismissed the picker / share sheet / dialog | Do nothing |
| `PlatformUnsupported(reason)` | Not available on this platform | Hide the feature |
| `PlatformPermissionDenied()` | OS blocked access (camera, photos, storage) | Point the user at Settings |
| `PlatformFailed(message, error, stackTrace)` | Supported, but failed at runtime | Show / report the error |

`PlatformPermissionDenied` extends `PlatformFailed`, so a bare `case PlatformFailed()` catches it too — put the specific arm *before* the generic one when denial deserves its own recovery (send the user to Settings), or drop it and let the failure arm handle everything. The payload inside `PlatformSupported` is never null.

Two shortcuts when a full `switch` is more than you need:

```dart
// just want the value, don't care why it's missing
final PickedAsset? asset = result.valueOrNull;

// collapse to one type without a switch statement
final label = result.when(
  supported: (asset) => asset.fileName ?? 'file',
  cancelled: () => 'cancelled',
  unsupported: (reason) => reason,
  failed: (message, error) => message,
);
```

`when` folds permission-denied into `failed` — reach for the `switch` when it needs its own path.

<details>
<summary><b>🧩 why a sealed result instead of just throwing?</b></summary>

<br>

Because two of the five outcomes aren't errors, and exceptions can't say so.

A user who opens the photo picker and taps **Cancel** did nothing wrong. A desktop that has **no camera** isn't broken. If those threw, every call site would wrap a `try/catch` and then guess, from the exception type or its message, whether to show an error, stay quiet, or hide a button. And a nullable return (`Future<PickedAsset?>`) is no better — `null` can't tell "cancelled" apart from "unsupported."

So the package spends a variant on each real outcome. `PlatformCancelled` and `PlatformUnsupported` are values, not failures; `PlatformFailed` is reserved for the genuine "supported, but it broke" case, with `PlatformPermissionDenied` as a named subtype because its recovery differs (send the user to Settings, don't retry). The result type is sealed, so the compiler flags any arm you forgot — you find out at build time, not from a user's crash report.

Throws are kept for one thing only: **programmer error**. Pass an empty list to `shareFiles` and it throws `ArgumentError` synchronously — that's a bug in the call, not a runtime state to branch on.

</details>

---

## Usage

Four doors off the container: `assetPicker`, `sharing`, `download`, `fileOpener`. Pick the one that fits what you're doing. Highlights below; every method and full signature lives in the [API reference](https://pub.dev/documentation/device_io/latest/).

### Pick

`deviceIO.assetPicker` covers images, video, mixed media, and generic files — single or multi.

```dart
final picker = deviceIO.assetPicker;

// images
await picker.pickImage(maxWidth: 1024, imageQuality: 85);
await picker.pickImages(limit: 5);          // never returns an empty list
await picker.captureImage();                // camera; Unsupported on desktop

// video + mixed
await picker.pickVideo();
await picker.captureVideo(maxDuration: Duration(minutes: 2)); // camera
await picker.pickMedia();                   // one image OR video
await picker.pickMultipleMedia(limit: 10);  // images and/or videos

// generic files, optionally filtered by extension
await picker.pickFile(allowedExtensions: ['mp3', 'wav']);
await picker.pickFiles();
```

`pickImages`, `pickFiles`, and the multi-media picks never surface an empty selection — that's `PlatformCancelled`, so you never branch on `list.isEmpty`. `limit` caps the count where the platform supports it and is ignored elsewhere. Hide the camera button when it isn't there:

```dart
if (picker.isCameraSupported) showCameraButton();
```

Camera capture runs on phones and tablets — native apps and mobile browsers alike. Desktop returns `PlatformUnsupported`. For `pickMedia`, branch on the result's `mimeType` to tell an image from a video:

```dart
if (result case PlatformSupported(:final value)) {
  final isVideo = value.mimeType.startsWith('video/');
}
```

<details>
<summary><b>🧩 what "lazy read" means for a picked file</b></summary>

<br>

A pick doesn't hand you bytes. It hands you a `PickedAsset` with two read callbacks, and **nothing is read until you call one:**

```dart
final small = await asset.readBytes();      // whole thing, one Uint8List
final chunks = asset.readStream();          // Stream<List<int>>, constant memory
```

Use `readBytes()` for avatars and thumbnails. Use `readStream()` for photos, videos, model files — anything you'd rather not hold in RAM. Pipe the stream straight into a save without buffering:

```dart
await deviceIO.download.saveStreamToDevice(
  byteStream: asset.readStream(),
  fileName: asset.fileName ?? 'video.mp4',
);
```

Each `readStream()` call returns a **fresh** stream, so you can read the same asset more than once. There's no `filePath` and no eager `bytes` field on purpose — paths don't exist on web, and eager bytes would OOM the first large file. Where the read comes from:

- Native picks read from disk on demand.
- Web image picks read from the browser blob on demand.
- Web generic-file picks are the one eager case — the file-picker plugin hands over bytes, not a blob reference.

</details>

### Share

`deviceIO.sharing` opens the OS share sheet (Web Share API on web). Text, one file, many files, or a stream — the adapter stages temp files for you.

```dart
final sharing = deviceIO.sharing;

await sharing.shareText(text: 'Check this out', subject: 'A link');

await sharing.shareFile(
  bytes: pngBytes,
  fileName: 'chart.png',
  text: 'This quarter',
);

// several files in one sheet
await sharing.shareFiles(
  files: [
    ShareFile(bytes: pngBytes, fileName: 'chart.png'),
    ShareFile(bytes: csvBytes, fileName: 'data.csv'),
  ],
);

// large file, without holding it in memory (native streams to disk;
// web buffers, because Web Share needs the whole file up front)
await sharing.shareFileStream(
  byteStream: asset.readStream(),
  fileName: 'recording.mp4',
);
```

Every share method takes an optional `sharePositionOrigin` — the anchor rectangle the iPadOS share popover points at. iPad needs it; hand over your button's global bounds. Every other platform ignores it. `shareFiles` throws `ArgumentError` on an empty list, because a share sheet with nothing in it is a bug in the call, not a runtime state.

<details>
<summary><b>🧩 what happens to a shared or opened file afterward?</b></summary>

<br>

Sharing bytes and opening bytes both need a real file on disk — the OS share sheet and the default viewer take a file, not a `Uint8List`. So the adapter **stages** one: it writes your bytes into a fresh temporary directory under the OS cache, with the real filename preserved (the share sheet shows `chart.png`, not a random hash).

That staged file is **deliberately not deleted** when the call returns. On Android the share `Future` resolves the moment the sheet closes — but the app you shared to reads the file *after* that, so deleting it eagerly would hand the receiver an empty file. The OS reclaims its cache directory on its own schedule; letting it do that is both correct and simpler than trying to guess when the receiver is done.

Filenames are sanitized before they touch the path (traversal sequences, Windows-reserved names, control characters), and every staging call gets its own directory, so two shares of `photo.png` never collide. None of this is anything you call — it's what `shareFile` / `shareFiles` / `openBytes` do for you.

</details>

### Save

`deviceIO.download` has two doors. `saveToDevice` writes silently; `saveAs` asks the user where.

```dart
final download = deviceIO.download;

// silent, no dialog — returns the path (null on web)
final result = await download.saveToDevice(bytes: csvBytes, fileName: 'export.csv');

// user picks the destination via the system dialog
await download.saveAs(bytes: pdfBytes, fileName: 'report.pdf', dialogTitle: 'Save report');

// stream a big file to disk chunk by chunk (constant memory on native)
await download.saveStreamToDevice(byteStream: asset.readStream(), fileName: 'video.mp4');
```

**Read this before you rely on `saveToDevice` on a phone.** On desktop it writes to the real Downloads folder. On mobile it writes to an **app-private** downloads folder (`Android/data/<pkg>/files/Download`, the iOS sandbox Downloads dir) — the user won't find it in their Files or Downloads app, and it's deleted on uninstall. For a save the user can actually see on mobile, use `saveAs`, which routes through the Android create-document dialog (public storage, no permissions) and the iOS Files export sheet.

Silent saves never clobber an existing file: a taken `report.pdf` becomes `report (1).pdf`, matching browser behavior, and unsafe characters in the name are sanitized away. Streaming saves write to a temporary `.part` file that only becomes the final file once the stream completes, so a failed stream leaves nothing behind. `mimeType` sets the blob content type on web; native platforms infer the type from the extension and ignore it.

### Open

`deviceIO.fileOpener` opens content in the platform's default viewer — Preview, Photos, a browser tab, whatever the OS associates with the type.

```dart
final opener = deviceIO.fileOpener;

// works everywhere — native stages a temp file, web opens a blob in a new tab
await opener.openBytes(bytes: pdfBytes, fileName: 'doc.pdf');

// open a path you already have (native only) — pairs with saveToDevice
final saved = await download.saveToDevice(bytes: bytes, fileName: 'report.pdf');
if (saved case PlatformSupported(value: final String path)) {
  await opener.openPath(filePath: path);
}
```

`openBytes` is the cross-platform path — use it when you have bytes and want them on screen. `openPath` takes an absolute path and returns `PlatformUnsupported` on web, where filesystem paths don't exist; feed the same bytes to `openBytes` there instead.

---

## Error handling

When something genuinely breaks, you get a `PlatformFailed` carrying three things: a human-readable `message` for a snackbar, plus the original `error` and its `stackTrace` for logging or crash reporting.

```dart
final result = await deviceIO.download.saveAs(bytes: bytes, fileName: 'report.pdf');
switch (result) {
  case PlatformSupported(:final value):
    showSaved(value);
  case PlatformCancelled():
    break; // dismissed the dialog — nothing to report
  case PlatformPermissionDenied():
    promptForSettings();
  case PlatformFailed(:final message, :final error, :final stackTrace):
    logger.report(message, error, stackTrace);
}
```

`message` is a diagnostic string, not a localized one — your app translates for its users. Permission denials arrive as `PlatformPermissionDenied` (a `PlatformFailed` subtype, see [Results](#results)) because the recovery differs: send the user to system settings, don't retry. The package maps each plugin's exact permission code to that variant, so you never string-match error text.

---

## Platform support

One API, six targets. Each capability is backed by a federated plugin (or a web API) underneath:

| Capability | Android | iOS | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| **Pick** | image_picker / file_picker | image_picker / file_picker | file_picker | file_picker | file_picker | image_picker / File System Access |
| **Share** | share_plus | share_plus | share_plus | share_plus | share_plus | Web Share API |
| **Save** | path_provider / SAF dialog | path_provider / Files export | path_provider / native dialog | path_provider / native dialog | path_provider / native dialog | blob download / File System Access |
| **Open** | open_filex | open_filex | OS open | OS open | OS open | blob in new tab |

Camera capture is available on phones and tablets — native apps and mobile browsers — and returns `PlatformUnsupported` on desktop.

<details>
<summary><b>🧩 how does one API stay honest across six platforms?</b></summary>

<br>

Your app never writes `kIsWeb`, and it never gets a fake answer. Two things make that true.

**Where a platform genuinely can't do something, you get a typed `PlatformUnsupported`** — never a silent no-op, never a faked success. `openPath` on web returns `Unsupported` because browsers have no filesystem paths; camera capture returns `Unsupported` on desktop. Every one of those claims was checked against the underlying plugin's source before it was written, rather than assumed.

The six-platform badge is also guarded. A cross-platform Flutter package silently drops a platform the moment a shared file imports something native-only, and two of the dependencies here (`share_plus`, `open_filex`) would do exactly that if imported the obvious way. So the package reaches them through their platform interface and method channel instead, and a [pana](https://pub.dev/packages/pana) check in the test suite fails the build if the six-platform score ever slips.

</details>

### Where saves land

The two save doors resolve differently per platform. This is the table to keep in mind:

| | `saveToDevice` (silent) | `saveAs` (user picks) |
|---|---|---|
| **Desktop** | Real Downloads folder | Native save dialog |
| **Android** | App-private dir (hidden from Files, gone on uninstall) | Create-document dialog → public storage |
| **iOS** | App sandbox Downloads (hidden from Files) | Files export sheet |
| **Web** | Browser download (browser decides location) | File System Access save dialog on Chromium; plain download elsewhere |

On web, `saveAs` on a Chromium browser opens a real save dialog through the File System Access API and writes to the file the user chose; on Firefox and Safari it falls back to a plain browser download.

### Browser support

There's no minimum-version table, because the web layer **feature-detects at runtime and degrades gracefully** instead of gating on a version:

- **File System Access** (the `saveAs` save dialog, lazy file-pick reads) is Chromium-only. Where it's absent — Firefox, Safari — `saveAs` becomes a plain download and file picks read eagerly via `withData`. Everything still works; the experience is just a notch plainer.
- **Web Share** availability varies by browser and by whether the page is served over HTTPS. A dismissed sheet comes back as `PlatformCancelled`.
- **Camera capture** works in mobile browsers (the file input's `capture` attribute); desktop browsers report `PlatformUnsupported`.

You never check any of this yourself. The package picks the best available path and hands you the same `PlatformResult` regardless.

---

## Not in the box

A short honest list — what the shipped package doesn't do, and what to reach for meanwhile. For the full status-per-capability picture, see the [capability roadmap](docs/CAPABILITY_ROADMAP.md).

- **Silent saves to *public* storage on mobile.** `saveToDevice` on a phone writes to app-private storage (see [Save](#save)). Making it land in public Downloads without a dialog would take first-party MediaStore native code — a step this package deliberately hasn't taken (see the [roadmap](docs/CAPABILITY_ROADMAP.md) for the reasoning). `saveAs` is the user-visible answer: public storage, through the system dialog, no permissions. Need true background exports? [Open an issue](https://github.com/whuppi/device_io/issues) — that's the reopen trigger.
- **Requesting permissions.** This package *surfaces* denials as `PlatformPermissionDenied`; it doesn't pop the permission prompt or manage the flow. Apps own their permission UX and their Info.plist / manifest entries. For an explicit request-and-check flow, use [`permission_handler`](https://pub.dev/packages/permission_handler).
- **A viewer widget.** `openBytes` and `openPath` open content in the OS default app — they don't draw it inside your UI. To render a PDF or image on screen, pair this with a viewer package ([`pdfx`](https://pub.dev/packages/pdfx) for PDFs, a gallery widget for images): pick and save here, display there.
- **`openPath` on web.** Filesystem paths don't exist in the browser, so `openPath` returns `PlatformUnsupported` there. `openBytes` is the web path — hand it the bytes and it opens a blob in a new tab.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the four adapters, the platform seam, lazy reads |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | What's shipped, what's planned, what won't happen |
| [Updating](docs/UPDATING.md) | Maintenance recipes and pinned source-of-truth links |
| [Migration](docs/MIGRATION.md) | Upgrading from the pre-release workspace API |
| [Contributing](CONTRIBUTING.md) | Setup, PR workflow, adding capabilities |

---

## License

MIT. See [LICENSE](LICENSE).
