# device_io example

A Flutter app exercising every `device_io` capability — pick, share, save,
and open files through one API. Four tabs, one per API surface, with a
global activity log showing every `PlatformResult` outcome. All demo bytes
are generated in code; nothing touches the filesystem or network to start.
Runs on macOS, iOS, Android, Windows, Linux, and web.

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

## Platform setup

The iOS `Info.plist` usage strings (photo library, camera, microphone) and
the macOS user-selected read-write entitlements are already configured in
this example.

## Tests

Integration tests land alongside the package test suite.
