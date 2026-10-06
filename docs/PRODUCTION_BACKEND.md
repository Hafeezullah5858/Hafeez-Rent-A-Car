# Production Backend Integration

The V5 application is deliberately safe to run offline without fake cloud credentials.

For production multi-device use, connect one of these backends:

## Firebase
- Firebase Authentication: email/password + email verification + password reset
- Firestore: users, vehicles, clients, rentals, payments, expenses
- Firebase Storage: vehicle/customer document images
- Firebase Cloud Messaging: rental/payment/expiry notifications
- App Check and Firestore Security Rules

## Supabase
- Supabase Auth: email/password + reset/verification
- Postgres: business records and accounting
- Storage: documents/photos
- Edge Functions: notifications and server-side workflows

Before enabling cloud sync, migrate existing local records and define role-based rules for Admin, Customer and Driver. Never put service-account private keys inside the mobile application.
