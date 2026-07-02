# device_io example

A Flutter app exercising every `device_io` capability — pick, share,
save, and open files through one API. Tap a button, watch the outcome
land in the activity log. All demo bytes are generated in code; nothing
touches assets or the network to start. Runs on macOS, iOS, Android,
Windows, Linux, and web.

## Run

```bash
cd example

# desktop
fvm flutter run -d macos

# web
fvm flutter run -d chrome

# any connected device
fvm flutter run -d <device>
```

## Tests

```bash
# host-VM journey matrix — the UI driven end to end through the real
# adapters against scripted plugin edges, across every device profile;
# no device needed:
cd example
fvm flutter test test/journeys

# integration smoke — the programmatic surfaces against REAL plugins:
fvm flutter test integration_test/device_io_smoke_test.dart -d macos
fvm flutter test integration_test/device_io_smoke_test.dart -d <device>

# or from the package root:
cd ..
make test-example-matrix
make test-example-macos
```

The host journeys stay in memory (no `dart:io`) — they drive the UI
through the real adapters against scripted plugin edges. Real
filesystem effects (silent saves with the no-clobber proof, streamed
saves, asset round-trips) live in the integration smoke, which runs on
a real device where async I/O behaves normally. Pickers, share sheets,
`saveAs`, and openers summon real dialogs and viewers, so they're
exercised by the package suites and the journeys instead.

## What's inside

Four tabs, one per API surface:

| Tab | API | What it covers |
|---|---|---|
| **Pick** | `assetPicker` | Gallery images (single + multi), camera capture, videos, mixed media, generic files. Picked assets are lazy — bytes are read on tap, never at pick time. |
| **Share** | `sharing` | Text, a single file, multiple files in one sheet, and a ~1MB byte stream. |
| **Save** | `download` | Silent save to downloads, a streamed save, and the user-picks-destination system dialog. |
| **Open** | `fileOpener` | In-memory bytes in the default viewer, and the last silently-saved path. |

Every call returns a sealed `PlatformResult`; one renderer switches the
family exhaustively and writes the outcome into the activity log, which
sits below the tabs — global, so a result is never hidden by tab
switching.

## One file on purpose

The whole app lives in `lib/main.dart` because pub.dev renders that
file as the package's Example tab — splitting it would hide everything
else from that page.

## Platform setup

The iOS `Info.plist` usage strings (photo library, camera, microphone)
and the macOS user-selected read-write entitlements are already
configured in this example — the same declarations the package README's
Install section walks consumers through.
