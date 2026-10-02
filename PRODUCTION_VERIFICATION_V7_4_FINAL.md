# V7.4 Final Production Verification Report

## Result
Source-level verification completed for the V7.4 production package.

### Verified
- ZIP archive integrity
- Required Flutter CI workflow is present
- `flutter pub get`, `flutter analyze`, `flutter test`, and debug APK build are configured in CI
- Vehicle P&L daily/weekly/monthly/custom date plumbing is present
- Vehicle comparison export and PDF plumbing is present
- Vehicle-specific CSV/PDF actions are present
- Initial rental payment creates both PaymentRecord and income ledger entry
- Subsequent payments create PaymentRecord and income ledger entry
- Payment amounts are bounded by rental outstanding balance
- Fuel and maintenance amounts/mileage are validated
- Historical outstanding uses payments up to the selected report end date
- Legacy rentals without PaymentRecord are handled without repeating the same payment in every later period
- Backup/restore includes vehicles, entries, customers, rentals, maintenance, fuel, drivers, payments, settlements, inspections, settings and audit logs
- Firestore rules enforce authenticated per-user document ownership
- PDF dependencies and branded assets are declared
- Production tests were strengthened for schema version, rental totals/deposit calculations, and vehicle payment non-duplication

## Important limitation
Flutter/Dart SDK is not installed in this execution environment. Therefore an actual `flutter analyze`, `flutter test`, and APK/AAB compilation could not be executed here. The repository CI workflow is configured to perform those checks on GitHub Actions using Flutter 3.35.7.

## Security note
Firestore currently enforces per-user ownership. Application roles are not a sufficient server-side security boundary; production multi-user role enforcement should use Firebase Custom Claims and corresponding Firestore Rules before exposing different accounts to different staff roles.

## Recommended release gate
1. Push this package to the GitHub `main` branch.
2. Let the Actions workflow run `pub get`, formatting, analyze, tests and debug APK build.
3. Fix any SDK/package-specific compile issue reported by CI.
4. Configure Firebase/FlutterFire and Android Firebase configuration before cloud-enabled production use.
5. Run a real-device acceptance test for rental creation, payment, return, vehicle P&L, fleet comparison, PDF printing and backup restore.
