# Permissions and privacy

PHNTM requires two macOS privacy permissions. Both are explained during first-run onboarding and continuously reflected in the menu bar status.

## Camera

Path in System Settings:

**Privacy & Security → Camera → PHNTM**

PHNTM uses camera access to:

- display the live preview;
- pass sample buffers to Apple Vision;
- detect up to two hand poses;
- draw the local hand skeleton and status indicators.

The application declares `NSCameraUsageDescription` in its generated Info.plist and includes the camera entitlement in `PHNTM.entitlements`.

### Camera data handling

- Frames remain in memory while the capture session is running.
- Frames are not written to disk.
- Images, video, and landmarks are not uploaded.
- The application contains no network client, analytics SDK, telemetry service, or remote API integration.
- Stopping the camera clears the published hand landmarks.

## Accessibility

Path in System Settings:

**Privacy & Security → Accessibility → PHNTM**

PHNTM uses Accessibility event-posting permission to:

- send Control-Tab and Control-Shift-Tab directly to frontmost Safari;
- send Page Up and Page Down directly to frontmost Safari;
- post standard macOS brightness media-key events.

The application checks permission with `CGPreflightPostEventAccess()` and opens the correct System Settings pane when access is unavailable.

PHNTM does not inspect the accessibility hierarchy, read text from other applications, capture keystrokes, or monitor user input.

## Why App Sandbox is disabled

The Xcode target disables App Sandbox because PHNTM must post system input events outside its own process. This makes the project suitable for direct Developer ID distribution rather than the current Mac App Store sandbox model.

The public Release configuration enables Hardened Runtime and is intended to be signed with a Developer ID Application certificate and notarized by Apple.

## Stored preferences

PHNTM stores only two local preferences through `UserDefaults`:

| Key | Purpose |
| --- | --- |
| `browserControlEnabled` | Remembers whether Safari commands are enabled |
| `completedOnboarding.v1` | Remembers whether the setup guide was completed |

No gesture history, camera data, browser data, or brightness history is persisted.

## Revoking access

Permissions can be revoked at any time in System Settings.

- Without Camera permission, PHNTM cannot start hand recognition.
- Without Accessibility permission, PHNTM reports a permission-required state and does not post Safari or brightness events.

After changing a permission, return to PHNTM. The application refreshes permission state whenever it becomes active.

## Accessibility identity and application updates

macOS associates Accessibility approval with the installed application's identity. For reliable behavior:

- run the app from `/Applications` for end-user testing;
- keep a consistent bundle identifier and signing identity;
- avoid moving the app after permission is granted;
- replace releases in the same location;
- sign public builds with the same Developer ID identity.

If macOS shows PHNTM as allowed but commands do not work:

1. Quit PHNTM.
2. Remove old PHNTM entries from the Accessibility list.
3. Move the current build to Applications.
4. Add or enable the current PHNTM application.
5. Relaunch it and verify that the menu bar no longer shows a permission warning.

Ad-hoc or unsigned development builds can receive different permission treatment from signed release builds. A successful command-line compilation does not prove that the launched copy has Accessibility approval.

## Output safety boundaries

Safari events are posted only after verifying that the active application has bundle identifier `com.apple.Safari`. Brightness events are emitted only after the complete two-palms-to-two-fists state sequence.

Both gesture engines require pose stabilization and explicit release before another command can fire.

## Security reporting

Permission-boundary or privacy concerns should be reported privately according to [SECURITY.md](../SECURITY.md), not posted with sensitive details in a public issue.
