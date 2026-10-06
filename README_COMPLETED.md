# Hafeez Rent A Car — Completed Local Management Build

This build expands the original app with a practical local rental-management workflow.

## Included
- Admin login and local credential settings
- Vehicle add/edit/delete and availability status
- Customer/client add/edit/delete
- CNIC, phone, address and notes
- Customer rental history
- Rental booking with pickup/return dates
- Daily rent, total rent, advance and remaining balance
- Rental payment collection
- Vehicle return/completion flow
- Automatic vehicle status changes for active rentals
- Income and expense records
- Maintenance/fuel expense records
- Dynamic dashboard counts and financial totals
- Business report summary
- Local persistence with SharedPreferences

## Important
This is a local/offline build. Data is stored on the device. Cloud sync, multi-user access, WhatsApp integration, PDF invoices and server-side authentication require a backend/service connection and credentials.

Default first-login credentials:
- Email: admin@hafeezrentacar.com
- Password: 123456

Change the password from More → Administration after first login.

## Version 4.1 - Role Based Login

Home page now provides three separate account portals:
- Admin Login: Admin ID/Email, Sign Up, Forgot/Reset Password
- Customer Login: Account ID, Sign Up, Forgot/Reset Password
- Driver Login: Account ID, Sign Up, Forgot/Reset Password

Customer and Driver accounts are stored locally on the device in this offline build. Password reset is a local reset by account ID. For production use, secure server-side authentication, OTP/email verification, and encrypted password handling should be connected.

## V4.2 Professional Profile & Form Validation
- Customer and Driver sign-up now collects Account ID, full legal name, email, mobile, CNIC, complete address, password and password confirmation.
- Email, mobile, CNIC, password and required-field validation is enforced before account creation.
- Customer/Driver login accepts Account ID or registered email.
- Password reset verifies Account ID/email + registered email + mobile for local/offline accounts.
- Customer records now include email and professional validation.
- Vehicle add/edit form validates make/model, registration and model year.
- All current data remains local/offline; real email OTP/SMS OTP verification requires a backend service such as Firebase/Supabase.


## Version 4.3 - Financial Dashboard & Reports

Added a professional admin financial dashboard with total income, expenses, net profit, outstanding customer balance, daily/weekly/monthly/yearly snapshots, custom date range reports, transaction history, PDF export and Excel (XLSX) export. Rental advances and customer payments are recorded as income transactions.


## V5.2 Premium 3D Admin UI
- Dark navy / gold professional dashboard styling.
- 3D-style Quick Actions: Add Car, Add Income, Add Expense, Add Ride.
- Elevated gradient action cards with accent icons and shadows.
- Professional dialog headers for Add/Edit Car, Add/Edit Ride, Add Income and Add Expense.
- Ride accounting remains integrated with Yango, inDrive, Offline, Direct Booking and City-to-City income/expense ledger.
- Dashboard quick actions are connected to the real local data and refresh the dashboard after save.
