# Premium V6.7 — Production Finance & Security Audit

## Security corrections
- Added capability enforcement to ledger entry updates.
- Added capability enforcement to rental status changes and rental return/finalization.
- Restricted local admin-role changes to the Owner role.

## Reporting upgrades
- Added management-level Reports & Control screen.
- Added finance reconciliation checks across payment transactions, rental paid totals, and ledger income.
- Added data-quality checks for orphan rentals, missing vehicle registration, missing driver license data, overdue rentals, and expiring vehicle documents.
- Added fleet profitability view.
- Added CSV exports for rentals, payments, ledger, and fleet profitability.

## Engineering notes
- No new runtime dependencies were added.
- Existing local/cloud persistence architecture is preserved.
- Flutter SDK is required to run `dart format`, `flutter analyze`, tests and a release build.
