# One identity, two operational workspaces

The public host accepts an optional `TruWorkspaceBuilder` through
`runRespondCrew`. The private TRU repository assembles the host with its own
module. No private source or repository credential is copied into this repo.
Normal RespondCrew builds do not require access to the TRU repo.

The private assembly pins a full host commit and injects a local package path
only into a disposable checkout. It builds the same Android/iOS/web application
and uses the existing Firebase Auth instance and user UID; there is no second
account or Firebase initialization.

## Navigation and access

- `/tookeskkonnad`: choose marine or TRU; TRU appears only after a positive
  `getTruContext` response. `/tru` also checks access when opened directly.
- `/uhingud`, `/keskus/sar`, `/keskus/tross`: existing marine organization and
  center authorization is unchanged.
- A builder is an integration hook, never an authorization bypass.
- Membership is checked at login, on app resume, and every 20 seconds while
  foregrounded. A failed check removes TRU access. A successful cached result
  becomes unusable after 45 seconds. Revocation therefore takes effect at the
  next check; this is not an instantaneous push-based revocation mechanism.
- Marine forms remain mounted when TRU membership changes. Auth account changes
  remount the keyed workspace and discard the previous user's module state.
- TRU data remains explicitly marked as in-memory demo data. Future persistent
  operations must each reauthorize membership server-side; a UI gate alone
  cannot protect operational data.

## Membership model (server only)

`truMemberships/{firebaseUid}` contains:

| Field | Constraint |
|---|---|
| active | boolean |
| role | member / coordinator / admin |
| regions | 1–4 unique values: Ida, Lääne, Lõuna, Põhja |
| validUntil | Firestore Timestamp or null |
| revision | integer >= 1 |
| updatedAt | server timestamp |
| updatedBy | authenticated platform administrator UID |

The existing default-deny Firestore rules deny client reads and all writes on
this new collection, including subcollections. No rules deployment is needed
for the new namespace. `getTruContext` reads only the authenticated caller's
membership. User-supplied UID and role fields cannot impersonate another user.

`getPlatformTruAccess` and `setTruAccess` require an existing platformAdmin or
platformOwner. Organization administrators and TRU coordinators cannot grant
membership. Every change is revision-checked and recorded in platformAudit
inside the same Firestore transaction. The administration dialog is under
Platform management → User accounts → TRU membership.

## Deployment and review

The callable functions must be deployed before enabling the combined app:

```
firebase deploy --only functions:getTruContext,functions:getPlatformTruAccess,functions:setTruAccess
```

Deployment has not been performed by this change. This does not migrate users,
assign anyone TRU permissions, or alter marine memberships. After reviewing the
host and private module PRs, build and test the combined app before distributing
it. The private workflow can produce a debug APK by manual dispatch.

Validation covers unauthorized grants, schema/region/role injection, revision
conflicts, audit creation, expiry, revocation, stale responses, auth identity,
workspace routing, marine draft stability, and denied direct Firestore access.
