# Android releases and update compatibility

Application ID: `krv.app`. The existing signing certificate is intentionally retained
to allow updates of earlier installations. Its origin is the former local debug
keystore; moving it does not turn it into a different production certificate.
Do not replace the key, regenerate the certificate, or uninstall the app to resolve
a signature mismatch. App-store signing requirements must be addressed separately.

Certificate SHA-256:
`b813d691b1b988a2caf4c56dd17959df3ef7269f6a57f3cdc8cc5fec1302750c`

## Local signing

Gradle reads `~/.krv-signing/signing.properties`, or the file specified by the
`KRV_SIGNING_PROPERTIES` environment variable. Keep it and the keystore private and
outside Git. Required Java properties: `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. Use an absolute path with forward slashes for storeFile.
The key and certificate must match the fingerprint above. Release builds fail if
configuration is missing; they never silently use a newly generated debug key.
Debug builds keep the standard development signing configuration.

Keep an encrypted offline copy of the signing directory in a separate safe place.
Both the keystore and its password are needed to recover future signing capability.
Do not publish these files, paste them into issues, or attach them to releases.
Changing the keystore password does not change the signing identity.

Build with `flutter build apk --release`. Verify package name, increasing versionCode,
certificate fingerprint and SHA-256 before attaching an APK to a versioned release.
Local signing uses the private configuration above. Automated releases use encrypted
GitHub Actions secrets; neither secret values nor signing files belong in Git.

## Obtainium

Add `https://github.com/olegegka/krv` as a GitHub source in Obtainium.
Release v4.5.1 contains one APK with versionName 4.5.1 and versionCode 13.
If that version is already installed, no update is expected until a newer release.
Future versions must retain the application ID and compatible signature and increase
versionCode. Allow Android's permission to install unknown apps for Obtainium when
prompted. Silent installation depends on Android and installer eligibility.

Export important measurements with photographs as `.krv` before the first update.
Keep the installed app and its storage; install updates over it. An update normally
retains local data, but signing cannot prevent application-level migration bugs.
After updating, check measurement counts, a previous record and its photographs.
If Android reports an incompatible signature, stop rather than uninstalling.

## Automated GitHub releases

The `Signed Android release` workflow runs when a stable `vX.Y.Z` tag is pushed.
Prepare a release through a pull request: update `pubspec.yaml` (both the version
and its increasing Android build number), app version references and CHANGELOG.
After checks pass and the pull request is merged, tag that commit and push the tag.
For example, a future `version: 4.5.2+14` must use tag `v4.5.2`.
Do not move an existing version tag or reuse a published version.

The workflow verifies that the commit belongs to main history, the tag matches
pubspec, and the version and build number exceed previous stable tags. It runs
formatting, analysis and all tests before building. The APK must have application
ID `krv.app`, the expected version, no debuggable flag and the certificate above.
The release is published only after its APK, SHA256SUMS.txt and build-info.json
have been uploaded to a draft. Published releases are never overwritten; failed
draft publication can be retried with GitHub's Re-run jobs button.

Repository Actions secrets: `KRV_KEYSTORE_BASE64`, `KRV_STORE_PASSWORD`,
`KRV_KEY_PASSWORD`, `KRV_KEY_ALIAS`. These contain the preserved PKCS12 identity,
not a newly generated key. Temporary signing files are removed after the build.
Do not print secrets or enable verbose shell tracing around signing commands.
Only the publishing job receives write access to repository contents.

Actions -> Signed Android release -> Run workflow on main performs a trial build
and saves a signed-apk artifact for 14 days. It does not publish or modify releases.
Use this to check infrastructure without inventing a new app version. For a real
release, push the version tag; merely changing pubspec or merging main is not a release.

Obtainium discovers each published release on its next refresh/background check.
GitHub cannot push an immediate update to a sleeping phone. Keep an offline copy
of the local signing directory: GitHub secrets cannot be downloaded for recovery.
