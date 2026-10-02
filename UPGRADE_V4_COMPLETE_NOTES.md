# Hafeez Rent A Car — Premium Upgrade V4 Complete

This upgrade keeps the V3 local-first architecture and adds the missing commercial workflow foundations without removing existing features.

## Added
- Expanded vehicle master data: chassis, engine, insurance company, purchase/market value and registration/insurance/token/fitness expiry dates.
- Expanded customer KYC: emergency contact and stronger profile workflow.
- Expanded rental model: discount, tax/other charges, late fee, damage fee, mileage limit, extra mileage, payment method, pickup/return locations, actual return time, deposit refund and cancellation reason.
- Total payable and remaining balance now account for rental adjustments.
- Automatic overdue rental detection on local reload.
- Dashboard overdue, fleet utilization and alerts indicators.
- Alerts & Expiry center for overdue rentals, receivables, licenses, vehicle documents and service due dates.
- Firebase admin account workflow with login, logout and password reset email.
- System information / module summary.
- Backup schema raised safely; old records remain backward compatible through defaults.

## Existing features preserved
- Fleet, customers, rentals, ledger, maintenance, fuel, reports, cloud sync, local storage, backup/restore, dark mode and CI workflow.

## Validation
Flutter SDK is not installed in the preparation environment, so authoritative validation must run through the included GitHub Actions workflow. The workflow should run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`.
