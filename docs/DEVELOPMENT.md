# Development and verification

## Prerequisites

- A Mac running macOS 14 or later.
- A current full Xcode installation with the macOS SDK.
- Git.
- A camera for live recognition testing.
- Accessibility approval for the exact app build used in output testing.

PHNTM uses only Apple frameworks and has no Swift Package Manager, CocoaPods, Homebrew, npm, or server dependency.

## Open the project

```bash
git clone https://github.com/arsenysmorodin/PHNTM.git
cd PHNTM
open PHNTM.xcodeproj
```

Choose the **PHNTM** scheme and the **My Mac** destination.

## Build configurations

| Configuration | Intended use | Notes |
| --- | --- | --- |
| Debug | Local development | App Sandbox disabled; no Hardened Runtime setting |
| Release | Distribution | App Sandbox disabled; Hardened Runtime enabled |

Shared target settings include:

- macOS deployment target `14.0`;
- Swift language version `5.0`;
- bundle identifier `arsenysmorodin.PHNTM`;
- marketing version `1.0.0`;
- camera usage description and entitlement.

## Command-line builds

### Debug

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project PHNTM.xcodeproj \
  -scheme PHNTM \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/PHNTM-Debug-DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Universal Release compilation check

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project PHNTM.xcodeproj \
  -scheme PHNTM \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/PHNTM-Release-DerivedData \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Verify architectures:

```bash
lipo -archs \
  /tmp/PHNTM-Release-DerivedData/Build/Products/Release/PHNTM.app/Contents/MacOS/PHNTM
```

Expected output:

```text
x86_64 arm64
```

If `xcodebuild` reports that the active developer directory is CommandLineTools, either use the `DEVELOPER_DIR` prefix above or select full Xcode:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## Source organization

| Path | Responsibility |
| --- | --- |
| `PHNTM/PHNTMApp.swift` | Main window, menu bar scene, root object lifetime |
| `PHNTM/AppController.swift` | Runtime orchestration and gesture priority |
| `PHNTM/Camera/CameraManager.swift` | Capture session, Vision request, landmark publication |
| `PHNTM/Gestures/GestureClassifier.swift` | Open-palm, pointing, and fist geometry |
| `PHNTM/Gestures/DirectionGestureEngine.swift` | Direction stabilization and release/rearm |
| `PHNTM/Gestures/BrightnessGestureEngine.swift` | Two-palms-to-two-fists state machine |
| `PHNTM/Browser/BrowserTabController.swift` | Permission check and Safari shortcut posting |
| `PHNTM/System/DisplayBrightnessController.swift` | Brightness media-key events |
| `PHNTM/Status/AppStatusStore.swift` | Status priority and transient events |
| `PHNTM/ContentView.swift` | Main diagnostics and controls |
| `PHNTM/Views/CameraPreview.swift` | Camera preview and landmark overlay |
| `PHNTM/Views/OnboardingView.swift` | First-run setup and permission flow |

See [Architecture](ARCHITECTURE.md) for detailed interactions.

## Concurrency conventions

- Keep UI-observable services on `@MainActor`.
- Configure and start/stop `AVCaptureSession` only on its session queue.
- Run Vision requests on the frame queue.
- Return published camera and recognition state to the main actor.
- Do not block a frame callback with event timing or UI work.
- Preserve the explicit gesture priority in `AppController`: brightness sequence first, directional sequence second.

## Gesture changes

When changing a classifier or timing constant:

1. Test incomplete landmark arrays and low-confidence joints.
2. Test false-positive cases, not only the intended pose.
3. Confirm a held pose emits one event.
4. Confirm release is required before the next event.
5. Confirm the brightness sequence cannot leak into directional recognition.
6. Verify visible status and menu bar feedback.
7. Repeat the manual matrix in [Gesture recognition](GESTURES.md).

Avoid basing a gesture on absolute pixel distance. Vision points are normalized; palm-relative lengths and joint angles are more stable across camera distance.

## Verification status

The repository currently has no XCTest target. Use all of the following before merging behavioral changes:

- `git diff --check`;
- Debug compilation;
- universal Release compilation;
- `lipo` architecture verification;
- manual Camera and Accessibility onboarding;
- live camera gesture tests;
- Safari focus and disabled-toggle negative tests;
- display dimming and release/rearm test.

Compilation checks do not validate the physical camera pose, installed app identity, Accessibility approval, Safari behavior, or display hardware response.

## Logging

Recognized actions are printed to the Xcode console:

```text
PHNTM: POINT LEFT
PHNTM: POINT RIGHT
PHNTM: POINT UP
PHNTM: POINT DOWN
PHNTM: DIM DISPLAY
```

Camera setup and Vision failures also include a `PHNTM:` prefix. Use the visible UI status together with logs; a recognized action followed by a focus warning is different from classifier failure.

## Packaging

Use the maintained scripts rather than manually assembling application bundles:

```bash
./scripts/package-local.sh
./scripts/package-release.sh
```

The first creates an ad-hoc local test DMG. The second requires Developer ID and notarization credentials. Full instructions are in [DISTRIBUTION.md](../DISTRIBUTION.md).

## Documentation changes

Keep these files synchronized with behavior:

- gesture mappings and timings in `README.md` and `docs/GESTURES.md`;
- component ownership in `docs/ARCHITECTURE.md`;
- permission use in `docs/PERMISSIONS_AND_PRIVACY.md`;
- target versions and commands in this file;
- signing and release steps in `DISTRIBUTION.md`;
- user-visible changes in `CHANGELOG.md`.
