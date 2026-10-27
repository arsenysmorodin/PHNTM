# Troubleshooting

Start with the menu bar status and the diagnostic rows in the main window. They distinguish missing permissions, missing hands, incomplete landmarks, recognized poses, output failures, and application-focus problems.

## PHNTM still reports a missing permission

### Camera

1. Open **System Settings → Privacy & Security → Camera**.
2. Enable the currently installed PHNTM application.
3. Return to PHNTM so it can refresh permission state.
4. If necessary, quit and relaunch PHNTM.

If no PHNTM entry appears, launch the current app and select **Allow Camera** in onboarding first.

### Accessibility

1. Quit PHNTM.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Remove stale PHNTM entries if multiple copies exist.
4. Move the current app to `/Applications`.
5. Add or enable that exact PHNTM copy.
6. Relaunch PHNTM.

Accessibility approval can stop matching after changing the signing identity, launching a different build path, or replacing an unsigned development copy. Use a consistently signed app at a stable path for real testing.

## Gestures are not recognized

Check the main window in order:

1. **Hand count:** both hands should be detected.
2. **Point count:** the total should approach `42 / 42 POINTS`.
3. **Open palm:** the safety palm should show ready.
4. **Command hand:** the pointing hand should show ready.
5. **Direction or brightness instruction:** hold the requested pose until it stabilizes.

Then improve capture quality:

- move both wrists and fingertips fully into frame;
- separate the hands so they do not overlap;
- face the palms toward the camera;
- increase front lighting;
- reduce bright light behind you;
- move slightly farther from the camera;
- use a clear index-finger direction rather than a diagonal pose.

Directional gestures are static; do not swipe. Hold the pointing pose briefly, then release it before repeating.

## Gesture is shown but Safari does nothing

Confirm all of the following:

- **Control Safari** is enabled in PHNTM;
- Accessibility status says access is granted;
- Safari is the active frontmost app;
- the current PHNTM copy is the one enabled in Accessibility;
- the pointing pose was released after the previous event.

PHNTM intentionally refuses to send browser commands to Chrome or any application other than active Safari.

The status text `Gesture detected — focus Safari` means recognition succeeded and only the focus safety check failed.

## A held gesture does not repeat

This is expected. Each stable pose emits one command. Release the pointing pose for at least a brief moment before showing it again.

For brightness, release the two fists and begin again with two open palms.

## Brightness gesture does not fire

Watch the brightness row:

- `SHOW TWO OPEN PALMS`: both hands have not yet been classified as open palms;
- `HOLD BOTH PALMS`: keep both palms stable;
- `CLOSE BOTH HANDS`: the gesture is armed;
- `HOLD BOTH FISTS`: both fists need a little more stabilization;
- `RELEASE TO REARM`: the previous command already fired.

Two fists shown without the initial two-open-palm phase are ignored intentionally.

If `DISPLAY DIMMED` appears but brightness does not change, verify Accessibility and test the normal keyboard brightness keys. Displays that do not respond to macOS brightness keys generally will not respond to PHNTM either.

## Brightness works but Safari control is off

This is expected when the **Control Safari** toggle is disabled. The brightness gesture is independent and remains active while camera tracking is running.

## Camera preview is black

- Confirm Camera permission.
- Quit other applications that may hold exclusive camera access.
- Stop and restart the camera from PHNTM.
- Disconnect and reconnect an external camera.
- Verify that macOS can use the camera in another trusted application.

If no camera is available, PHNTM reports `No camera was found.`

## Build fails because Xcode is not selected

Error:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory ... is a command line tools instance
```

Use full Xcode for the command:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

Or change the system selection:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## SwiftUI macro errors during an automated build

Errors such as a missing `SwiftUIMacros.StateMacro` combined with `sandbox_apply: Operation not permitted` can be an execution-sandbox problem rather than a source error. Retry the same build from a normal local Terminal or Xcode environment with full access to Xcode's plugin server.

## Where to look for diagnostics

- Main PHNTM window for landmark and pose state.
- Menu bar for permission, ready, gesture, and error status.
- Xcode console for `PHNTM:` recognition and camera messages.
- macOS Console for code-signing or TCC permission diagnostics.

When filing an issue, include macOS version, Mac model/architecture, camera type, installed app path, signing type, visible PHNTM status, relevant console lines, and exact reproduction steps. Do not attach private camera recordings unless they are necessary and intentionally redacted.
