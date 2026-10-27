# Distribution

PHNTM is distributed outside the Mac App Store because it requires Accessibility access to send Safari shortcuts and system brightness events. Public builds must use a Developer ID Application certificate and Apple notarization so Gatekeeper can verify them normally.

## Supported Macs

- macOS 14 or later.
- Apple silicon and Intel.
- A built-in or connected camera.
- Safari as the frontmost application for browser commands.
- A display that responds to standard macOS brightness controls for dimming.

## Release outputs

| Workflow | Output | Intended use |
| --- | --- | --- |
| Local package | `dist/PHNTM-<version>-local.dmg` and `.sha256` | Testing on the build Mac only |
| Public release | `dist/PHNTM-<version>.dmg` and `.sha256` | Signed, notarized distribution |

Build and distribution output is ignored by Git through `build/` and `dist/`.

## Local test DMG

Run:

```bash
./scripts/package-local.sh
```

The script:

1. removes the previous local packaging workspace;
2. builds a universal Release app for `arm64` and `x86_64`;
3. copies the app into a DMG staging directory;
4. applies an ad-hoc signature with a stable designated requirement;
5. verifies the app signature;
6. creates a compressed DMG with an Applications shortcut;
7. writes a SHA-256 checksum.

The local package is for same-Mac testing only. Do not publish it: another Mac will not trust it through Gatekeeper, and Accessibility approval may behave differently from a Developer ID build.

## Public release prerequisites

### Apple Developer identity

Install a valid **Developer ID Application** certificate and its private key in the login keychain.

List available identities:

```bash
security find-identity -v -p codesigning
```

The release script automatically selects the first Developer ID Application identity. To choose one explicitly:

```bash
export DEVELOPER_ID_APPLICATION='Developer ID Application: Name (TEAMID)'
```

### Notarization credentials

Create an app-specific password for the Apple ID associated with the developer team, then save the credentials in Keychain once:

```bash
xcrun notarytool store-credentials 'PHNTM-notary' \
  --apple-id 'APPLE_ID_EMAIL' \
  --team-id 'TEAM_ID' \
  --password 'APP_SPECIFIC_PASSWORD'
```

Credentials remain in Keychain and are not stored in the repository.

To use another profile name:

```bash
export NOTARY_PROFILE='another-profile'
```

## Build the public DMG

Run:

```bash
./scripts/package-release.sh
```

The script:

1. validates the Developer ID identity;
2. validates the notarization profile;
3. builds a universal Release app;
4. signs the app with Developer ID, Hardened Runtime, timestamp, and project entitlements;
5. verifies the signature;
6. submits an app archive to Apple notarization and waits for the result;
7. staples and validates the app ticket;
8. creates and signs a compressed DMG with an Applications shortcut;
9. notarizes, staples, and validates the DMG;
10. runs Gatekeeper assessments for the app and DMG;
11. writes a SHA-256 checksum.

The script stops on the first failed command. A package is not ready for publication unless signing, notarization, stapling, and Gatekeeper assessment all succeed.

## Versioning

Before a public release, update both Xcode target values:

- `MARKETING_VERSION`: user-visible semantic version, for example `1.1.0`;
- `CURRENT_PROJECT_VERSION`: monotonically increasing build number.

Also update [CHANGELOG.md](CHANGELOG.md) and verify that the generated DMG filename contains the intended version.

Do not change the bundle identifier or Developer ID identity casually. Accessibility consent is sensitive to application identity, and an unnecessary identity change can force users to approve the app again.

## Verify artifacts

Verify the checksum:

```bash
shasum -a 256 -c dist/PHNTM-<version>.dmg.sha256
```

Inspect architectures:

```bash
lipo -archs build/public-release/dmg/PHNTM.app/Contents/MacOS/PHNTM
```

Expected:

```text
x86_64 arm64
```

Inspect the signature and Gatekeeper result:

```bash
codesign --verify --deep --strict --verbose=2 build/public-release/dmg/PHNTM.app
spctl --assess --type execute --verbose=4 build/public-release/dmg/PHNTM.app
spctl --assess --type open --context context:primary-signature --verbose=4 dist/PHNTM-<version>.dmg
```

## Clean-machine acceptance test

Test the final DMG on a Mac that has not run the development build:

1. Download the DMG and verify its checksum.
2. Open it without bypassing Gatekeeper.
3. Drag PHNTM to Applications.
4. Complete onboarding and grant Camera and Accessibility.
5. Quit and relaunch the app.
6. Confirm the menu bar status remains ready.
7. Confirm all four directional gestures in frontmost Safari.
8. Confirm no Safari event is sent when Safari is not frontmost.
9. Disable **Control Safari** and confirm recognition remains visible without browser output.
10. Confirm two open palms followed by two fists dims the display once.
11. Keep the fists closed and confirm the brightness event does not repeat.
12. Release and repeat the sequence to confirm rearming.
13. Move focus, close the main window, and verify menu bar operation.

## Publish on GitHub

For each public version:

1. Push the release commit and tag.
2. Create an annotated tag such as `v1.1.0`.
3. Push the tag.
4. Create a GitHub Release from that tag.
5. Use the matching section from `CHANGELOG.md` as release notes.
6. Attach the notarized DMG and its `.sha256` file.
7. Do not attach the `-local.dmg` artifact.

Example tag commands:

```bash
git tag -a v1.1.0 -m 'PHNTM 1.1.0'
git push origin v1.1.0
```

Tagging and GitHub Release creation are intentionally separate from the packaging scripts so a maintainer can inspect the final artifacts before publication.

## Release checklist

- [ ] Working tree is clean.
- [ ] `main` contains the intended release commit.
- [ ] Marketing version and build number are updated.
- [ ] Changelog and documentation match behavior.
- [ ] Debug and universal Release builds succeed.
- [ ] Developer ID signing succeeds.
- [ ] App notarization and stapling succeed.
- [ ] DMG notarization and stapling succeed.
- [ ] Gatekeeper accepts both app and DMG.
- [ ] Checksum validation succeeds.
- [ ] Clean-machine onboarding and relaunch succeed.
- [ ] Safari positive and negative cases pass.
- [ ] Brightness sequence and rearm pass.
- [ ] GitHub Release contains the public DMG and checksum only.
