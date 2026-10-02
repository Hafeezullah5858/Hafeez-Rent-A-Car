# V5 Quality Checklist

Before production release:

- `flutter pub get`
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- Configure Firebase only with the real project credentials.
- Verify Android release signing before publishing.
- Test restore from a fresh backup on a clean installation.
- Test rental overlap, payment limits, overdue state and duplicate registration validation.
