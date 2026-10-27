# Changelog

All notable changes to PHNTM are documented in this file.

The project follows semantic versioning for public releases.

## Unreleased

### Documentation

- Added a complete GitHub README and detailed architecture, gesture, privacy, development, troubleshooting, contribution, security, and distribution documentation.

## 1.0.0 — 2026-10-21

### Added

- Native SwiftUI macOS application and menu bar utility.
- AVFoundation camera capture with Vision hand-pose recognition for up to two hands.
- Live camera preview with hand skeleton and landmark count.
- Static two-hand Safari gesture model: one open safety palm and one pointing command hand.
- Previous and next Safari tab commands.
- Safari page-up and page-down commands.
- Gesture stabilization and explicit release/rearm behavior.
- Safe output targeting limited to active frontmost Safari.
- Two-open-palms-to-two-fists display dimming sequence.
- Display brightness adjustment to one step above minimum using macOS media-key events.
- Permission, ready, guard-palm, gesture, brightness, and error menu bar states.
- English onboarding for gestures, Camera permission, and Accessibility permission.
- Persistent onboarding completion and Safari-control preference.
- Universal Apple silicon and Intel Release builds.
- Local ad-hoc and public Developer ID/notarized DMG packaging scripts.

### Security and privacy

- Camera and gesture processing remain on-device.
- No camera recording, telemetry, analytics, or network integration.
- Release builds use Hardened Runtime.
