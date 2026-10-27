# Security policy

PHNTM processes live camera frames and holds Accessibility permission, so privacy and unintended input-event behavior are treated as security-sensitive.

## Supported versions

Until a formal release channel is established, security fixes are applied to the latest `main` branch and the newest published release, if one exists. Older development builds are not supported.

## Report privately

Use GitHub's private security-advisory reporting for this repository when available. If private reporting is unavailable, contact the maintainer privately through the GitHub profile rather than opening a public issue with exploit details.

Include:

- affected commit or version;
- macOS version and Mac architecture;
- installed application path and signing type;
- required Camera or Accessibility state;
- reproduction steps;
- impact and expected behavior;
- logs or proof of concept with secrets and personal camera content removed.

Please do not publicly disclose the issue until a fix or coordinated disclosure plan is available.

## In scope

- camera frames or hand landmarks leaving the local process unexpectedly;
- camera recording or persistence without clear user action;
- input events sent without a completed supported gesture;
- Safari events sent to an unverified target application;
- repeated actions that bypass release/rearm safeguards;
- Accessibility permission misuse;
- code-signing, notarization, or packaging weaknesses that could enable tampering;
- sensitive information included in logs, artifacts, or the repository.

## Usually not a vulnerability

- ordinary Vision misclassification without a permission or safety-boundary bypass;
- recognition failure caused by lighting, framing, or unsupported camera hardware;
- brightness events ignored by an external monitor that does not support macOS brightness keys;
- unsigned local builds being rejected by Gatekeeper;
- Accessibility permission needing to be granted again after the app identity or path changes.

These may still be valid bug reports when they include reproducible behavior.

## Security model

- Camera processing is local and in memory.
- The codebase contains no network or analytics integration.
- Safari output checks the frontmost application's bundle identifier before posting directly to its process.
- Brightness output requires a stabilized two-phase gesture.
- Both gesture engines require release before another event.
- Output controllers verify Accessibility event-posting permission.
- Public packages are expected to use Developer ID signing, Hardened Runtime, notarization, stapling, and Gatekeeper verification.

See [Permissions and privacy](docs/PERMISSIONS_AND_PRIVACY.md) and [Distribution](DISTRIBUTION.md) for implementation and release details.
