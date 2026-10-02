# Hafeez Rent A Car — Premium V5 Upgrade Pass

## Visual system
- Luxury black / warm-gold brand direction.
- Consistent Material 3 typography hierarchy.
- Rounded 14–18px controls/cards for a modern business-app feel.
- Stronger button/input states and accessible contrast.
- Light and dark themes share the same brand language.
- Existing HRC app icon retained as the single brand mark.

## Business-logic hardening
- Prevents vehicle registration-number duplicates during edits.
- Prevents overlapping active/reserved rentals for the same vehicle.
- Payment additions cannot exceed the complete payable rental amount.
- Overdue dashboard count includes normalized overdue records.

## Engineering notes
- Existing local-first/Firebase architecture is preserved.
- No new runtime dependency was introduced for the theme pass.
- Firebase credentials remain intentionally external to the repository.
- CI remains responsible for formatting, analysis, tests and Android build.

## Next implementation wave
1. Driver profiles + driver/vehicle assignments.
2. Role-based admin permissions and audit log.
3. Dedicated payments/transactions ledger.
4. Vehicle/customer document storage and inspection workflow.
5. Rental agreement and print/share-ready receipts.
6. Fleet settlement for Yango/inDrive/offline earnings.
7. PDF/CSV reporting and scheduled backup.
