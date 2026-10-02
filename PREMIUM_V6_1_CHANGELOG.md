# Premium V6.1 — Rental Close, Inspection & Reporting

## Added
- Rental agreement preview with customer/vehicle/charges/signature section.
- Return inspection records with mileage, fuel level, condition, damage charge and notes.
- One-step Return & Close workflow: saves inspection, closes rental, updates vehicle mileage/status, records deposit refund expense.
- Inspection records included in local backup/restore and Firebase cloud sync.
- Reports now include driver performance summary.
- Rental CSV export copied directly to clipboard from Reports.
- Local schema upgraded from 14 to 15.

## Safety
- Deposit refund cannot exceed available security deposit.
- Negative mileage/damage/refund values are rejected.
- Existing local data structures are preserved.

## Verification
Flutter SDK is not installed in this runtime, so `flutter analyze`, `flutter test`, and APK build were not executed here. Run the project Quality Checklist in GitHub Actions before production deployment.
