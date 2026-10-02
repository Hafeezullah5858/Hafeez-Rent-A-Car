# Premium V6.9 — Document Center

## Added
- Dedicated Document Center module in desktop sidebar and mobile navigation.
- Rental agreement access per rental.
- Payment receipt preview generated from live payment history.
- Return & settlement document preview from return inspection data.
- Copy-to-clipboard for business documents.
- Business settings (name, contact, address, currency, footer) are used in generated documents.
- Search rentals by rental ID, customer, vehicle, or plate.

## Engineering
- No new runtime dependency.
- Existing local/cloud data models preserved.
- Documents are copy-ready text previews; PDF/printing requires a later platform-specific package.
- Flutter SDK was not available in the build environment, so analyze/test/build were not executed here.
