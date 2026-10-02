# V7.4 Complete Audit & Fixes

## Checked
- Vehicle-wise daily/weekly/monthly/custom P&L calculations
- Fleet comparison calculations and exports
- Rental payment accounting and payment history
- Fuel and maintenance validation
- Historical outstanding balance logic
- Legacy rental payment fallback
- PDF/CSV report wiring and asset references
- Local persistence, backup/restore and Firebase business sync paths
- Role checks and audit logging

## Fixes applied
1. Initial rental payments are now written to both Payment History and the income ledger, preventing missing income in vehicle reports.
2. Initial rental payment is validated against the rental amount.
3. Fuel and maintenance records now reject invalid/negative amounts and mileage.
4. Vehicle P&L no longer carries an old rental's full legacy paid amount into every later reporting period.
5. Historical outstanding is calculated as of the selected report end date instead of using today's balance.
6. App version bumped to 2.2.1+14.

## Remaining production dependency
Flutter SDK is not installed in the audit environment, so `flutter analyze`, `flutter test`, and APK/AAB compilation could not be executed here. Firebase role enforcement also still requires server-side Custom Claims/Firestore Rules; the client-side role selector must not be treated as the sole security boundary.
