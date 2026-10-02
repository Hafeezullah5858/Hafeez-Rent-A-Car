# Hafeez Rent A Car — Premium V6 Finance Upgrade

## Added
- PaymentRecord model with rental/customer/vehicle links, amount, date, method, reference and note.
- Payment history is now persisted separately from the rental's aggregate paidAmount.
- Rental payments are blocked when they exceed the outstanding balance.
- Every rental payment creates a dedicated payment record plus an income ledger entry.
- DriverSettlement model for salary, commission, advances, deductions and net payable.
- Driver settlement dialog from the Drivers module.
- Local backup/restore now includes payments and driver settlements.
- Firebase sync now includes `payments` and `driver_settlements` collections.
- Schema version raised from 13 to 14.

## Engineering notes
- Existing rental totals remain backward-compatible.
- Existing backups without the new arrays remain importable because the new sections are optional.
- Flutter build/analyze/test could not be executed in this environment because the Flutter SDK is not installed.
