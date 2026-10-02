# Premium V6.2 — Admin & Business Control

## Added
- Business Settings: name, phone, email, address, currency, default tax, receipt footer.
- Admin role profiles: Owner, Manager, Accountant, Operator, Viewer.
- Capability checks for role-sensitive settings workflow.
- Local audit log with timestamp, actor, action, entity and details.
- Audit log backup/restore and Firebase sync.
- Business settings backup/restore and Firebase sync.
- Schema version 16.
- Existing rental/payment/settlement workflows preserved.

## Important security note
The role selector is an application-level permission layer. Firebase currently remains UID-scoped. For production multi-user security, Firestore custom claims/server-side role enforcement should be configured; UI roles alone must not be treated as a security boundary.

## Verification
Flutter SDK is not installed in this build environment, so flutter analyze/test/build could not be executed here. Run the project's GitHub Actions workflow and the QUALITY_CHECKLIST commands before production release.
