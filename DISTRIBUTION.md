# PHNTM distribution

PHNTM is distributed outside the Mac App Store because it needs Accessibility access to send keyboard events to Safari. Public builds must use a Developer ID Application certificate and Apple notarization so Gatekeeper can verify them normally.

## Supported Macs

- macOS 14 or later
- Apple silicon and Intel
- A built-in or connected camera
- Safari as the frontmost application while gestures are used

## Create a local test DMG

```sh
./scripts/package-local.sh
```

The output is written to `dist/PHNTM-1.0.0-local.dmg`. It is ad-hoc signed and intended only for local verification. Do not publish it: Gatekeeper will not trust it on another Mac.

## Prepare public release credentials

1. Install a valid `Developer ID Application` certificate, including its private key, in the login keychain.
2. Create an app-specific password for the Apple ID connected to the developer team.
3. Save the notarization credentials once:

```sh
xcrun notarytool store-credentials "PHNTM-notary" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

Credentials stay in Keychain and are not stored in the repository.

## Build the public DMG

```sh
./scripts/package-release.sh
```

The release script:

1. builds a universal Release app;
2. signs it with Developer ID and Hardened Runtime;
3. submits the app to Apple notarization and staples the ticket;
4. creates and signs a DMG with an Applications shortcut;
5. notarizes and validates the DMG;
6. writes the DMG and its SHA-256 file to `dist/`.

Set `NOTARY_PROFILE` when using a profile name other than `PHNTM-notary`. Set `DEVELOPER_ID_APPLICATION` to choose a specific certificate when more than one Developer ID identity is installed.

## Release checklist

- Increment `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode target.
- Run the public packaging script without bypassing notarization.
- Install the resulting DMG on a different Mac and confirm Camera and Accessibility onboarding.
- Confirm all four gestures in frontmost Safari.
- Publish both the DMG and matching `.sha256` file.
