# Firebase setup — one time only

1. Create a Firebase project.
2. Add Android app package name: `hafeez_rent_a_car`.
3. Enable Authentication -> Sign-in method -> Email/Password.
4. Create Firestore Database.
5. Install FlutterFire CLI:
   `dart pub global activate flutterfire_cli`
6. From the project root run:
   `flutterfire configure`
7. Deploy the included rules:
   `firebase deploy --only firestore:rules`
8. Run the app again.

`flutterfire configure` generates `lib/firebase_options.dart` for your Firebase project. It is intentionally not included in this ZIP because it contains project-specific configuration.

## Important data-safety note
Firebase setup does not replace or delete local records. The app starts local-first, then merges local records with the signed-in cloud account. Each ledger record has a stable ID and update timestamp. Deleted entries also create cloud tombstones so an old copy does not reappear during a later sync.
