# Premium V7.2 — Vehicle-Level Profitability & Period Reports

## What changed
- Added separate Vehicle Performance Report for each vehicle.
- Daily, Weekly, Monthly and Custom date ranges.
- Shows rental billed, rental collected, other income, total income, fuel, maintenance, other expenses, total expenses, net result and current outstanding.
- Shows rental count, fuel litres and service records.
- Downloadable CSV per selected vehicle and period using the system share/save sheet.
- Printable/shareable A4 PDF per selected vehicle and period.
- Existing fleet profitability calculation corrected to avoid double-counting rental payments that already exist as ledger income.
- No database schema change required; reports are calculated from existing vehicle, rental, payment, ledger, fuel and maintenance records.

## Reporting logic
- Rental payments are taken from payment transactions.
- Ledger income categorized as `Rental payment` is excluded from direct income to prevent double counting.
- Fuel and maintenance are treated as vehicle expenses.
- Vehicle-linked ledger expenses are included as other expenses.
- Older rentals without payment transaction records use their stored `paidAmount` as a legacy fallback.

## Verification
- Source-level structural checks completed.
- Flutter SDK is not installed in the current environment, so `flutter analyze`, `flutter test` and APK/AAB build must be verified in GitHub Actions.
