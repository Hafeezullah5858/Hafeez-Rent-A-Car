# Premium V6.3 — Security & Role Hardening

## Included
- Admin role is now persisted per local account scope.
- Core write operations enforce role capabilities in the controller, not only in the UI.
- Fleet, ledger, customer, rental, payment, settlement, driver, maintenance and fuel mutations now reject unauthorized roles.
- Role changes are recorded in the audit log.
- Firebase sign-in restores the saved role for that account.

## Important security note
These are application-level controls. For production multi-user security, Firebase Custom Claims / Firestore security rules must also enforce roles server-side. A local UI role must never be treated as sufficient authorization for sensitive cloud data.

## Verification
Flutter SDK is not installed in the current build environment, so `flutter analyze`, `flutter test`, and APK compilation were not executed here. Run the project CI workflow to verify formatting, analysis, tests and build.
