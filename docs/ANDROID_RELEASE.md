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
Signing secrets are not uploaded to GitHub; APK signing currently happens locally.

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
