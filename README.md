# Hafeez Rent A Car

A local-first Flutter Rent-A-Car management application with optional Firebase account sync.

## Main modules
- Dashboard: business position, daily income/expense, receivables, fleet status and active rentals.
- Vehicles: vehicle profile, plate, model, year, color, fuel type, mileage and availability status.
- Customers: contact/CNIC/license information and rental history.
- Rentals: booking period, daily rate, total rent, advance, security deposit, payments, remaining balance and completion status.
- Operations: maintenance/service records and fuel records.
- Reports: income, expenses, rental revenue, receivables and vehicle profitability.
- Backup/Restore: JSON backup includes vehicles, ledger, customers, rentals, payments, maintenance and fuel.
- Local-first storage: the app remains usable without Firebase.
- Firebase: optional email/password account and cloud sync.

## Build
The repository workflow pins Flutter and runs formatting, analysis, tests and an Android APK build.
Firebase configuration is optional for local mode; follow `firebase_setup.md` to enable cloud accounts.

## Premium Upgrade V2
This build introduces the premium transaction flow, polished income/expense confirmation, refined business dashboard styling, and mobile-first commercial UI treatment while preserving the existing local-first data and cloud-sync architecture.


## Premium V5 upgrade pass
- Reworked light/dark Material 3 theme with a consistent luxury black/gold visual system.
- Standardized typography, input fields, buttons, cards, navigation and spacing.
- Added safer rental date-overlap validation to prevent double-booking a vehicle.
- Payment additions now respect the full rental payable amount (rent + tax + fees - discount).
- Overdue rental dashboard count now includes records whose status was normalized to `overdue`.
- Vehicle edits now prevent duplicate registration numbers.
- App version bumped to 1.5.0+6.

Note: Firebase production configuration remains environment-specific and must be supplied before a release build.
