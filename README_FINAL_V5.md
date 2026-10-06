# Hafeez Rent A Car — Professional V5.0

## Included in this final build

- Admin / Customer / Driver portals
- Account ID + email login
- Strong password validation
- Password reset with local identity verification
- SHA-256 password hashing for locally stored passwords, with migration of older local records
- Customer and driver verification flag
- Vehicle fleet management
- Vehicle mileage, insurance expiry, registration/token expiry and notes
- Customer CNIC, driving license number/expiry and profile records
- Rental booking, advance, remaining balance, security deposit and payment method
- Driver assignment per rental
- Payment ledger and income/expense tracking
- Vehicle-wise profitability
- Daily / weekly / monthly / yearly / custom financial reports
- PDF financial reports
- Excel financial reports
- Rental invoice/receipt PDF
- Rental agreement PDF
- Customer portal with available cars, booking/payment history and profile
- Driver portal with assigned jobs and profile
- Expiry/reminder center
- Business JSON backup/share
- Premium dark/gold Material 3 interface

## Important production note

This build is a complete local/offline business-management application. It stores records on the device using SharedPreferences. Real multi-device cloud synchronization, email OTP, SMS OTP and server-side authentication require a Firebase/Supabase project and its credentials; this ZIP intentionally does not contain fake credentials or pretend that local verification is cloud verification.

## First login

Admin: `admin@hafeezrentacar.com`
Password: `123456`

Change the default password immediately from Administration. New passwords are stored in SHA-256 form locally.

## Build

The project requires Flutter/Dart SDK. From the project directory:

```bash
flutter pub get
flutter build apk --release
```

For a Play Store release, configure the Android application ID, signing key, privacy policy and production backend before publishing.


## V5.1 Ride Accounting Upgrade

The final build includes an integrated ride-income and ride-expense module for:
- Yango
- inDrive
- Offline/direct bookings
- City-to-City / Intercity rides

Each ride records source, service type, vehicle, optional driver, customer, pickup/drop-off, date, distance, fare, platform commission, fuel, toll/motorway/parking, driver expense/share, other expense and payment method.

For every ride, the app automatically creates linked ledger entries using the ride ID as the reference, so editing a ride replaces its linked accounting entries instead of duplicating them. Net ride profit is calculated as fare minus all ride expenses. Ride transactions are included in the existing financial reports, PDF/Excel exports, dashboard totals, vehicle profitability and business backup.

The project remains local/offline-first. Real Yango/inDrive API synchronization, live trip import, SMS/email OTP and cloud multi-device sync require the respective production services/API credentials; the ride module itself works without an internet connection because records are stored locally.


## V5.2 Premium 3D Admin UI
- Dark navy / gold professional dashboard styling.
- 3D-style Quick Actions: Add Car, Add Income, Add Expense, Add Ride.
- Elevated gradient action cards with accent icons and shadows.
- Professional dialog headers for Add/Edit Car, Add/Edit Ride, Add Income and Add Expense.
- Ride accounting remains integrated with Yango, inDrive, Offline, Direct Booking and City-to-City income/expense ledger.
- Dashboard quick actions are connected to the real local data and refresh the dashboard after save.
