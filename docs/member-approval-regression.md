# Member approval regression

Scope: preserve administrator approval when joining an approved organization by code, including rejoining after removal. Based on main `f0972e34163c253dead820e8ebc97955cc6034c6`.

## Behaviour

- Code-based joining creates an inactive `pending` member with level `none`. It never switches the user's active organization before approval.
- An active administrator of that organization can approve or reject the request in Members. Review changes only status, active flag and server timestamp.
- Active members submitting the same code keep their existing role and level. Removed ordinary members can request approval again. Rejected or otherwise disabled memberships require administrator contact.
- Existing administrator-issued, email-bound invitations retain their separate acceptance flow: the administrator has already granted the invitation.

## Security assumptions and limits

Membership IDs remain `userId_organizationId`. New requests require matching organization references, restricted fields and server timestamps. The server accepts an inactive request for an approved organization; a join code is a client discovery mechanism, not the authorization boundary. Only admin approval or a valid administrator-issued invite grants membership access.

Existing legacy authorization branches are retained. This is a focused correction, not a complete security audit or certification of the roughly 2,600-line ruleset. Some denied legacy operations reach the expression budget; tested positive operations complete successfully. Broader rules simplification is outside this change.

## Verification

Firestore emulator: 36 tests pass, including new-member creation/read, malformed fields, wrong identity/document ID/organization, inactive organizations, forbidden active membership, self/ordinary/other-organization approval, removed-member rejoin, atomic activation bypass, valid admin approval and rejection, admin-issued invite acceptance for new/pending/removed members and fabricated invite denial. Existing role, equipment and operation-log tests also pass. Invitation updates are checked early to avoid exhausting the rule expression budget before reaching this legitimate path.

Flutter: analyzer and 29 existing tests pass. The new administrator controls still require the real-device test; unit tests do not establish that the whole approval flow works on a phone.

## Release order

Deploy these corrected rules and distribute the matching app build together. The original main build still attempts immediate active membership on code join and will be denied by the corrected rules. Do not publish the earlier unmodified-main draft from Firebase Console.

After deployment, compare the active rules source to this file and test request → admin approval → organization selection with two accounts. The Android release checklist is in `android-final-device-checklist.md`.
