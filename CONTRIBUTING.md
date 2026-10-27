# Contributing

Thank you for improving PHNTM. Gesture-control changes affect camera privacy, Accessibility output, and system behavior, so contributions should preserve the project's deliberate safety boundaries.

## Before starting

Read:

- [README.md](README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Gesture recognition](docs/GESTURES.md)
- [Permissions and privacy](docs/PERMISSIONS_AND_PRIVACY.md)
- [Development and verification](docs/DEVELOPMENT.md)

For large behavioral changes, open an issue first and describe the gesture, target action, false-positive controls, permission implications, and user-visible feedback.

## Development setup

```bash
git clone https://github.com/arsenysmorodin/PHNTM.git
cd PHNTM
open PHNTM.xcodeproj
```

The project has no third-party dependencies. Use a full Xcode installation and the PHNTM macOS scheme.

## Design principles

- Process camera data locally.
- Never record or upload camera frames.
- Require deliberate, stabilized gestures.
- Emit one action per pose and require release before repetition.
- Keep brightness recognition isolated from Safari recognition.
- Verify the target application before posting browser events.
- Surface permission, recognition, action, and error state visibly.
- Avoid adding permissions without a clear user-facing need and documentation update.
- Keep Safari-only scope unless a change is explicitly designed and reviewed for another application.

## Code style

- Follow the existing Swift formatting and naming style.
- Keep UI-observable services on `@MainActor`.
- Preserve queue confinement in `CameraManager`.
- Prefer scale-relative geometry and joint angles over fixed image distances.
- Keep state-machine timing constants named and centralized.
- Use localized, actionable error messages.
- Do not add third-party dependencies for functionality available in Apple frameworks without discussing the tradeoff first.

## Verification

Before opening a pull request:

1. Run `git diff --check`.
2. Build Debug.
3. Build a universal Release configuration for `arm64` and `x86_64`.
4. Run the manual matrix in [docs/GESTURES.md](docs/GESTURES.md).
5. Test Camera and Accessibility onboarding with the exact launched app copy.
6. Test Safari frontmost and non-frontmost behavior.
7. Test held-pose suppression and release/rearm.
8. Test display brightness only on hardware where normal macOS brightness keys work.

Document any step that could not be performed.

## Documentation requirements

Update documentation in the same pull request when changing:

- supported gestures or actions;
- recognition thresholds or state transitions;
- permissions or stored data;
- minimum macOS, Swift, or Xcode requirements;
- architecture or file ownership;
- packaging, signing, notarization, or release output;
- user-visible behavior recorded in the changelog.

## Pull requests

Keep pull requests focused. Include:

- the user problem and intended behavior;
- implementation summary;
- safety and false-positive considerations;
- permission or privacy impact;
- exact build and manual test results;
- screenshots or short recordings when the UI or gesture feedback changes.

Do not include signing certificates, notarization credentials, provisioning secrets, personal camera recordings, DerivedData, or generated DMGs.

## Security issues

Do not disclose a permission bypass, unintended event posting, or privacy issue in a public issue. Follow [SECURITY.md](SECURITY.md).

## License

No open-source license is currently included. A contribution cannot be assumed to change the repository's copyright or licensing terms.
