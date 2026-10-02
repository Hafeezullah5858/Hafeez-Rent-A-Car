# Project preflight

## Completed in this release
- Removed the duplicate `createState()` declaration from the app root.
- Added customer, rental, maintenance and fuel data models.
- Added persistent local storage and backup/restore for the new modules.
- Added Firebase collections for customers, rentals, maintenance and fuel.
- Added dashboard fleet/rental/receivable metrics.
- Added vehicle status management.
- Added rental payment tracking and vehicle availability updates.
- Added maintenance and fuel records with mileage tracking.
- Added vehicle profitability reporting.
- Kept the existing ledger and local-first data protection.
- Kept the Flutter CI workflow pinned and validation-oriented.

## Validation limitation
The execution environment used to prepare this archive does not contain the Flutter SDK, so `flutter analyze`, `flutter test` and `flutter build apk` cannot be executed here. The GitHub workflow runs those commands on a clean Flutter runner before an APK is accepted.
