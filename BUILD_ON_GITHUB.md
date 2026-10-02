# Build Hafeez Rent A Car on GitHub

This project is deliberately safe to upload from a phone: the ZIP does not depend on a locally installed Flutter/Android SDK.

## One-time upload
Upload the contents of this folder to the `main` branch of the empty `Hafeez-Rent-A-Car` repository.

## Automatic verification
GitHub Actions will:
1. Install the current Flutter stable SDK.
2. Generate the Android platform wrapper.
3. Install dependencies.
4. Run Dart formatting checks.
5. Run `flutter analyze`.
6. Run `flutter test`.
7. Build a debug APK.
8. Upload the APK as an Actions artifact.
9. Commit the generated `android/` folder back to `main` after a successful push.

After the first successful run, the repository itself contains the generated Android project.

## Firebase
Firebase is intentionally not given fake credentials. To activate real cloud sync, connect your own Firebase project with FlutterFire and commit the generated `lib/firebase_options.dart` plus Android Firebase configuration. The app remains usable locally until Firebase is configured.
