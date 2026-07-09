<!--
  Banner stays <picture> for GitHub's dark/light. pub.dev strips <picture>
  when sanitizing the README, so the publish step flattens it to the inner
  <img> via `tool/ci/release.sh --stamp-readme` (the repo copy is untouched).
  Drop both once pub.dev renders <picture>. Tracking:
  dart-lang/pub-dev#5923, dart-lang/pub-dev#6363, google/dart-neats#383.
-->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)"  srcset="assets/banner_dark-web-min.webp">
    <source media="(prefers-color-scheme: light)" srcset="assets/banner_light-web-min.webp">
    <img alt="device_io — cross-platform device IO for Flutter"
         src="assets/banner_light-web-min.webp" width="100%">
  </picture>
</p>

<p align="center">
  <a href="https://pub.dev/packages/device_io"><img src="https://img.shields.io/pub/v/device_io.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/device_io/score"><img src="https://img.shields.io/pub/likes/device_io" alt="likes"></a>
  <a href="https://pub.dev/packages/device_io/score"><img src="https://img.shields.io/pub/points/device_io" alt="pub points"></a>
  <a href="https://github.com/whuppi/device_io"><img src="https://img.shields.io/github/stars/whuppi/device_io?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

Pick images and files, share through the OS sheet, save to the device, open in the default viewer. One API on iOS, Android, macOS, Windows, Linux, and web.

Every call returns a typed result instead of throwing. A cancelled picker, an unsupported platform, and a real failure are three distinct values: not one exception to decode, and no `kIsWeb` in your app code.

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

Then call `DeviceIO()` once at startup and keep the result (see [Quick start](#quick-start)). The underlying plugins are federated, so there's no per-platform Dart to wire up.

Each platform *does* need its permission and entitlement setup below — the OS requires it, and no package can add it.

### iOS

Add the usage descriptions your app triggers to `ios/Runner/Info.plist`. Write your own copy — the OS shows these strings in the permission prompt:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Lets you pick photos to attach and share.</string>
<key>NSCameraUsageDescription</key>
<string>Lets you capture a photo or video from the camera.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used while recording video from the camera.</string>
```

Skip the keys for features you don't use: no camera capture, no `NSCameraUsageDescription`.

Set your iOS deployment target to **14.0**; `file_picker` 12's Swift Package requires it.

<details>
<summary><b>🧩 where to set the iOS 14 floor</b></summary>

<br>

Set `platform :ios, '14.0'` in `ios/Podfile`, and `IPHONEOS_DEPLOYMENT_TARGET = 14.0` on the Runner target in Xcode. Older scaffolds default to 13.0 and fail the build with `requires minimum platform version 14.0`. The [example app](example/) has both set if you'd rather copy from a working one.

</details>

### Android

No permissions, no manifest entries. Picking goes through the Android photo picker and the Storage Access Framework; `saveAs` writes through the system create-document dialog. None needs a runtime permission or a `<uses-permission>` line.

The only requirement is recent build tools: **AGP 8.12.1 · Gradle 8.13 · Kotlin 2.2.0** (via `share_plus` 13). Current Flutter scaffolds already ship newer, so most apps do nothing; only an old one has to bump.

<details>
<summary><b>🧩 the exact Android tooling floors</b></summary>

<br>

`share_plus` 13 is the binding one: `file_picker` 12 only needs AGP 8.5.2, under that. device_io's own example is CI-built on **AGP 9 / Gradle 9 / Kotlin 2.3**, what current Flutter scaffolds ship. Older apps: bump those in `settings.gradle` and the Gradle wrapper before the first build.

</details>

### macOS

The App Sandbox gates file access behind entitlements. Add these to **both** `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<!-- saveAs + file picking — locations the user chooses in a dialog -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<!-- silent save into the real Downloads folder -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

Skip the Downloads entitlement if you only use `saveAs` — a silent `save` returns `Failed` without it.

### Linux, Windows, Web

Nothing to add. They work as soon as the dependency resolves.

---

## Quick start

Construct once, then reach for the four capabilities off it. Here's pick-an-image-then-share-it — the whole round trip:

```dart
import 'package:device_io/device_io.dart';

// once, at app startup — keep the instance around
final deviceIO = DeviceIO(
  config: DeviceIOConfig(downloadsSubfolder: 'MyApp'),
);

// pick, then share the bytes
final picked = await deviceIO.picker.pickImage();
if (picked case Success(value: final asset)) {
  await deviceIO.sharer.shareFile(
    bytes: await asset.readBytes(),
    fileName: asset.fileName ?? 'photo.png',
    text: 'Look at this!',
  );
}
```

That's the shape of every call: ask a capability, get a `Outcome`, match the outcome you care about. `pickImage`, `shareFile`, `save`, `openBytes` — same shape, a different verb.

The `if (... case ...)` above handles just the happy path. To react to *every* outcome, `switch` over the sealed result and let the compiler check each arm (see [Results](#results)).

---

## Results

Every method returns a `Outcome<T>`. Five outcomes, each a distinct value:

| Variant | Means | Typical handling |
|---|---|---|
| `Success(value)` | It worked; `value` is the payload | Use it |
| `Cancelled()` | User dismissed the picker / sheet / dialog | Do nothing |
| `Unsupported(reason)` | Not available on this platform | Hide the feature |
| `PermissionDenied()` | OS blocked access (camera, photos, storage) | Point the user at Settings |
| `Failed(message, error, stackTrace)` | Supported, but failed at runtime | Show / report the error |

Consume it with an exhaustive `switch` — the compiler makes you handle every outcome:

```dart
switch (await deviceIO.picker.pickImage()) {
  case Success(:final value):
    await upload(await value.readBytes());
  case Cancelled():
    break; // nothing to do
  case PermissionDenied():
    openAppSettings();
  case Unsupported(:final reason):
    hideFeature(reason);
  case Failed(:final message):
    showError(message);
}
```

`PermissionDenied` extends `Failed`, so a bare `case Failed()` catches it too. Put the specific arm *before* the generic one when denial deserves its own recovery; drop it and the failure arm handles everything.

The value inside `Success` is never null.

There are deliberately no `isSupported` / `valueOrNull` / `when` shortcuts. A sealed result read through an escape hatch stops being exhaustive — and that's the point: the compiler catches the outcome you forgot.

<details>
<summary><b>🧩 why a sealed result instead of just throwing?</b></summary>

<br>

Because two of the five outcomes aren't errors, and exceptions can't say so.

A user who opens the photo picker and taps **Cancel** did nothing wrong. A desktop with **no camera** isn't broken. If those threw, every call site would wrap a `try/catch` and then guess, from the exception type or its message, whether to show an error, stay quiet, or hide a button. A nullable return (`Future<PickedAsset?>`) is no better — `null` can't tell "cancelled" apart from "unsupported."

So the package spends a variant on each real outcome. `Cancelled` and `Unsupported` are values, not failures; `Failed` is reserved for the "supported, but it broke" case, with `PermissionDenied` as a named subtype because its recovery differs (send the user to Settings, don't retry). The result is sealed, so the compiler flags any arm you forgot — you find out at build time, not from a crash report.

Throws are kept for one thing only: **programmer error**. Pass an empty list to `shareFiles` and it throws `ArgumentError` synchronously — that's a bug in the call, not a runtime state to branch on.

</details>

---

## Usage

Four doors off the container: `picker`, `sharer`, `saver`, `opener`. Pick the one that fits. Highlights below; every method and full signature lives in the [API reference](https://pub.dev/documentation/device_io/latest/).

### Pick

`deviceIO.picker` covers images, video, mixed media, and generic files — single or multi.

```dart
final picker = deviceIO.picker;

// images
await picker.pickImage(options: ImageOptions(maxWidth: 1024, quality: 85));
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

// a folder — feeds saveInto for pick-once-save-many (Unsupported on web)
await picker.pickDirectory(dialogTitle: 'Choose an export folder');
```

A few notes:

- The multi-picks never surface an empty selection — that's `Cancelled`, so you never branch on `list.isEmpty`.
- `limit` caps how many the user can pick where the platform supports it, and is ignored elsewhere.
- `ImageOptions` (`maxWidth`, `maxHeight`, `quality`) resizes and recompresses images. A picked video comes back untouched.

Hide the camera button when it isn't there:

```dart
if (picker.isCameraSupported) showCameraButton();
```

Camera capture runs on phones and tablets (native apps and mobile browsers). Desktop returns `Unsupported`.

For `pickMedia`, branch on the result's `mimeType` to tell an image from a video:

```dart
if (result case Success(:final value)) {
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

Use `readBytes()` for avatars and thumbnails. Use `readStream()` for photos, videos, model files — anything you'd rather not hold in RAM. Pipe the stream straight into a save, no buffering:

```dart
await deviceIO.saver.saveStream(
  byteStream: asset.readStream(),
  fileName: asset.fileName ?? 'video.mp4',
);
```

Each `readStream()` call returns a **fresh** stream, so you can read the same asset more than once. There's no `filePath` and no eager `bytes` field on purpose — paths don't exist on web, and eager bytes would OOM the first large file. Where the read comes from:

- Native picks read from disk on demand.
- Web image picks read from the browser blob on demand.
- Web generic-file picks read on demand too: via File System Access where the browser has it, otherwise through the file-picker plugin's own blob read. The one exception is a *multi*-file pick without File System Access (Firefox, Safari), which buffers the selection up front.

</details>

### Share

`deviceIO.sharer` opens the OS share sheet (the Web Share API on web). Text, one file, many files, or a stream. The adapter stages temp files.

```dart
final sharer = deviceIO.sharer;

await sharer.shareText(text: 'Check this out', subject: 'A link');

await sharer.shareFile(
  bytes: pngBytes,
  fileName: 'chart.png',
  text: 'This quarter',
);

// several files in one sheet
await sharer.shareFiles(
  files: [
    ShareFile(bytes: pngBytes, fileName: 'chart.png'),
    ShareFile(bytes: csvBytes, fileName: 'data.csv'),
  ],
);

// large file, without holding it in memory (native streams to disk;
// web buffers, because Web Share needs the whole file up front)
await sharer.shareFileStream(
  byteStream: asset.readStream(),
  fileName: 'recording.mp4',
);
```

Every share method takes an optional `sharePositionOrigin` — the anchor rectangle the iPadOS share popover points at. iPad needs it (hand over your button's global bounds); every other platform ignores it.

`shareFiles` throws `ArgumentError` on an empty list — a share sheet with nothing in it is a bug in the call, not a runtime state.

<details>
<summary><b>🧩 what happens to a shared or opened file afterward?</b></summary>

<br>

Sharing and opening bytes both need a real file on disk: the OS share sheet and the default viewer take a file, not a `Uint8List`. So the adapter **stages** one: it writes your bytes into a fresh temporary directory under the OS cache, with the real filename preserved (the share sheet shows `chart.png`, not a random hash).

That staged file is **deliberately not deleted** when the call returns. On Android the share `Future` resolves the moment the sheet closes, but the app you shared to reads the file *after* that, so deleting it eagerly would hand the receiver an empty file. The OS reclaims its cache directory on its own schedule — simpler than guessing when the receiver is done.

Filenames are sanitized before they touch the path (traversal sequences, Windows-reserved names, control characters), and every staging call gets its own directory, so two shares of `photo.png` never collide. None of this is anything you call — it's what `shareFile` / `shareFiles` / `openBytes` do.

</details>

### Save

`deviceIO.saver` has two doors: `save` writes silently, `saveAs` asks the user where.

```dart
final saver = deviceIO.saver;

// silent, no dialog
final result = await saver.save(bytes: csvBytes, fileName: 'export.csv');
if (result case Success(value: SavedAtPath(:final path))) {
  // native: a real path you can reopen. On web it's SavedByBrowser instead —
  // the browser owns the file, there is no path.
}

// user picks the destination via the system dialog
await saver.saveAs(bytes: pdfBytes, fileName: 'report.pdf', dialogTitle: 'Save report');

// stream a big file to disk chunk by chunk (constant memory on native)
await saver.saveStream(byteStream: asset.readStream(), fileName: 'video.mp4');

// save many files into a folder the user picked once (native only)
final dir = await deviceIO.picker.pickDirectory();
if (dir case Success(:final value)) {
  await saver.saveInto(directory: value, bytes: csvBytes, fileName: 'export.csv');
}
```

**Before you rely on `save` on a phone:** it writes to an **app-private** folder there (invisible in the Files app, gone on uninstall). For a save the user can find, use `saveAs` (system dialog, public storage, no permissions). And if the file was never *for* the user — you're storing your app's own data — reach for a storage engine like [`cellar_flutter`](https://pub.dev/packages/cellar_flutter) instead of a save door.

`pickDirectory` + `saveInto` is the pick-once-save-many flow: one folder dialog, then any number of silent saves into it, each with the same sanitize + no-clobber guarantees as `save`. Both return `Unsupported` on web (browsers expose no directory paths) — `saveAs` per file is the web equivalent.

Full per-platform breakdown in [Where saves land](#where-saves-land).

Three things the saver handles:

- **Never clobbers** — a taken `report.pdf` becomes `report (1).pdf`, and unsafe characters in the name are sanitized out.
- **Atomic streams** — a streaming save writes to a `.part` file, renamed only once the stream finishes; a failure leaves nothing behind.
- **`mimeType`** — sets the blob content type on web; native infers it from the extension.

### Open

`deviceIO.opener` opens content in the platform's default viewer: Preview, Photos, a browser tab, whatever the OS ties to the type.

```dart
final opener = deviceIO.opener;

// works everywhere — native stages a temp file, web opens a blob in a new tab
await opener.openBytes(bytes: pdfBytes, fileName: 'doc.pdf');

// open what you just saved — no destructuring, works with any SaveLocation
final saved = await deviceIO.saver.save(bytes: bytes, fileName: 'report.pdf');
if (saved case Success(:final value)) {
  await opener.open(value);
}

// or open a raw path you already have (native only)
await opener.openPath(filePath: '/some/absolute/path/report.pdf');
```

`openBytes` is the cross-platform path — reach for it when you have bytes to put on screen.

`open(SaveLocation)` closes the save→open loop: a `SavedAtPath` opens at its path; a `SavedByBrowser` download returns `Unsupported` (the browser owns that file — there's no handle to reopen).

`openPath` takes an absolute path and returns `Unsupported` on web, where filesystem paths don't exist. Feed the same bytes to `openBytes` there instead.

---

## Error handling

When something breaks you get a `Failed` carrying three things: a human-readable `message` for a snackbar, plus the original `error` and its `stackTrace` for logging or crash reporting.

```dart
final result = await deviceIO.saver.saveAs(bytes: bytes, fileName: 'report.pdf');
switch (result) {
  case Success(:final value):
    showSaved(value);
  case Cancelled():
    break; // dismissed the dialog — nothing to report
  case PermissionDenied():
    promptForSettings();
  case Failed(:final message, :final error, :final stackTrace):
    logger.report(message, error, stackTrace);
}
```

`message` is a diagnostic string, not a localized one — your app translates for its users.

Permission denials arrive as `PermissionDenied` (a `Failed` subtype, see [Results](#results)) because the recovery differs: send the user to system settings, don't retry. The package maps each plugin's exact permission code to that variant, so you never string-match error text.

---

## Platform support

One API, six targets. The matrix below is per **method**, and every cell is a typed answer:

- ✅ **works** — same call, same result shape
- ⚠️ **works, with a platform nuance** — see the matching note
- ❌ **returns `Unsupported`** — a typed result your code can branch on, never a crash or a silent no-op; its note says why and what to use instead

| What you call | Android | iOS | macOS | Windows | Linux | Web |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Pick images / videos / media | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Pick generic files | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️¹ |
| Camera capture | ✅ | ✅ | ❌⁷ | ❌⁷ | ❌⁷ | ⚠️² |
| `pickDirectory` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌⁸ |
| Share text / files / streams | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️³ |
| `save` / `saveStream` (silent) | ⚠️⁴ | ⚠️⁴ | ✅ | ✅ | ✅ | ⚠️⁵ |
| `saveAs` (dialog) | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️⁶ |
| `saveInto` (picked folder) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌⁸ |
| `openBytes` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `openPath` / `open(SaveLocation)` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌⁹ |

1. Single file picks read lazily everywhere. A **multi**-file pick buffers up front on Firefox/Safari (no File System Access there); Chromium stays lazy.
2. Mobile browsers ✅ (the file input's `capture` hint opens the camera). Desktop browsers ignore that hint — they'd silently show a plain file picker instead — so the package answers ❌ there rather than fake a capture.
3. Rides the browser's Web Share API: needs HTTPS, and *file* sharing is supported in fewer browsers than text. Where it's absent you get `Unsupported`, not a broken sheet.
4. Saves succeed but land in **app-private** storage — invisible in the Files app, gone on uninstall. For a save the user can find, use `saveAs`. Details in [Where saves land](#where-saves-land).
5. Becomes a browser download — the browser decides the location, and a stream is buffered first (browsers can't stream without a dialog).
6. File System Access dialog on Chromium (real streaming writes); plain download on Firefox/Safari.
7. Desktop has no system camera dialog to borrow — the image_picker desktop implementations throw unless you build your own capture UI. An in-app camera is a widget's job: use the [`camera`](https://pub.dev/packages/camera) plugin. Picking an *existing* photo works fine (`pickImage`).
8. Browsers don't expose directory paths, so there's no folder to pick or save into. The web equivalent of the pick-once-save-many flow is `saveAs` per file.
9. Filesystem paths don't exist on web, and a downloaded file belongs to the browser (no handle to reopen). `openBytes` is the web way to put content on screen.

The rule behind every ❌ and ⚠️: **the package never guesses.** Where a platform can't do something you get a typed `Unsupported` to branch on — hide the button, or take the note's fallback. Your app never writes `kIsWeb`.

<details>
<summary><b>🧩 what's under each verb?</b></summary>

<br>

Each capability wraps the battle-tested federated plugin for its job — this package adds the typed results, the lazy reads, and the cross-platform honesty on top:

| Capability | Android | iOS | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| **Pick** | image_picker / file_picker | image_picker / file_picker | file_picker | file_picker | file_picker | image_picker / File System Access |
| **Share** | share_plus | share_plus | share_plus | share_plus | share_plus | Web Share API |
| **Save** | path_provider / SAF dialog | path_provider / Files export | path_provider / native dialog | path_provider / native dialog | path_provider / native dialog | blob download / File System Access |
| **Open** | open_filex | open_filex | OS open | OS open | OS open | blob in new tab |

How the six-platform guarantee holds under the hood is in [Architecture](docs/ARCHITECTURE.md).

</details>

### Where saves land

The two save doors resolve differently per platform:

| | `save` (silent) | `saveAs` (user picks) |
|---|---|---|
| **Desktop** | Real Downloads folder | Native save dialog |
| **Android** | App-private dir (hidden from Files, gone on uninstall) | Create-document dialog → public storage |
| **iOS** | App sandbox Downloads (hidden from Files) | Files export sheet |
| **Web** | Browser download (browser decides location) | File System Access dialog on Chromium; plain download elsewhere |

On web, the Chromium save dialog comes from the File System Access API, writing straight to the file the user chose. Firefox and Safari fall back to a plain browser download.

`saveInto` writes to whatever directory you hand it — typically one from `pickDirectory` — so it lands wherever the user chose. Both are native-only (`Unsupported` on web).

### Which browsers?

All of them — you don't pick a minimum browser, and you don't check one either. Every call looks at what the user's browser can actually do **at that moment** and takes the best route it finds: Chrome gets the nicer paths (a real save dialog, files read only when needed), Firefox and Safari get the simpler ones (a plain download, files read up front). That's all the ⚠️ web notes in the matrix are. Your code sees the same `Outcome` either way.

---

## Not in the box

What the shipped package doesn't do, and what to reach for meanwhile. For the full per-capability status, see the [capability roadmap](docs/CAPABILITY_ROADMAP.md).

- **Silent saves to *public* storage on mobile.** `save` on a phone writes to app-private storage (see [Save](#save)). Landing in public Downloads silently needs first-party MediaStore code, which this package skips ([roadmap](docs/CAPABILITY_ROADMAP.md) has the reasoning). `saveAs` is the answer: public storage, system dialog, no permissions. Need background exports? [Open an issue](https://github.com/whuppi/device_io/issues).
- **Requesting permissions.** This package *surfaces* denials as `PermissionDenied`; it doesn't pop the permission prompt or manage the flow. Apps own their permission UX and their Info.plist / manifest entries. For an explicit request-and-check flow, use [`permission_handler`](https://pub.dev/packages/permission_handler).
- **A viewer widget.** `openBytes` and `openPath` open content in the OS default app — they don't draw it inside your UI. To render a PDF or image on screen, pair this with a viewer ([`pdfx`](https://pub.dev/packages/pdfx) for PDFs, a gallery widget for images): pick and save here, display there.
- **`openPath` on web.** Filesystem paths don't exist in the browser, so `openPath` returns `Unsupported` there. `openBytes` is the web path — hand it the bytes and it opens a blob in a new tab.
- **Drag-and-drop.** A drop target is a widget — a UI concern this package deliberately stays out of. Use [`desktop_drop`](https://pub.dev/packages/desktop_drop) for the drop surface; the dropped bytes flow straight into `share` / `save` / `openBytes` here.
- **Progress callbacks.** None of the wrapped plugins expose byte-level progress hooks. If you need one for a big save, count chunks in your own stream before handing it to `saveStream` — the stream seam makes that a five-line wrapper on the caller's side.
- **Opening URLs.** `open*` is for files/bytes, not links. [`url_launcher`](https://pub.dev/packages/url_launcher) owns URI opening; wrapping it here would add a dependency without adding a guarantee.
- **Storing your app's own files.** Every door here moves files between your app and the **user** (their picker, their share sheet, their Downloads). Files your app keeps for itself — caches, user content, databases of blobs — belong in a storage engine: [`cellar_flutter`](https://pub.dev/packages/cellar_flutter) gives you a ready-made one on the same six platforms (scoping, encryption seam, streaming, atomic writes). Save here when the user should see the file; store there when they shouldn't.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the four capabilities, the platform seam, lazy reads |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | What's shipped, what's planned, what won't happen |
| [Updating](docs/UPDATING.md) | Maintenance recipes and pinned source-of-truth links |
| [Contributing](CONTRIBUTING.md) | Setup, PR workflow, adding capabilities |

---

## License

MIT. See [LICENSE](LICENSE).
