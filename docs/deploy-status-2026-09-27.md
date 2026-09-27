# RespondCrew deployment — 27 September 2026

Firestore rules and `sendCalloutAlarmNotification` are deployed to `respondcrew`. Device end-to-end testing remains outstanding.

## Verified deployment

- Active Firestore rules were retrieved using Firebase MCP and match the local `firestore.rules` byte for byte (96,435 characters). SHA-256 after normalizing CRLF to LF: `cfb06a348c348dcf89ae887cc3c59af6c7b6e1a9d4d1cbf5920db4d91add1c22`.
- Function: `sendCalloutAlarmNotification`, generation 2, state **ACTIVE**, region `europe-north1`.
- Runtime: **nodejs22**, updated `2026-09-27T15:54:47.329306036Z`.
- Revision: `sendcalloutalarmnotification-00001-lix`.
- Trigger: `google.cloud.firestore.document.v1.created`; database and namespace `(default)`; path `callouts/{calloutId}`; trigger region `europe-north1`; retries disabled.
- Memory 256 MiB, 1 CPU, timeout 60 s, concurrency 80, minimum instances 0. No explicit maximum instance count returned by the Functions API.
- Service account: `420319876617-compute@developer.gserviceaccount.com`. Existing project roles include Editor, Eventarc Event Receiver and Cloud Run Invoker. No additional manual role grants were made.
- No secret environment variables are configured. The alarm uses Admin SDK credentials and FCM; SMTP is unrelated to alarm delivery.
- Runtime logs confirm the container startup probe succeeded on port 8080 after one attempt. No actual test callout/push was sent to live members; startup is not an end-to-end delivery test.

The first Functions attempt hit Eventarc service-agent permission propagation. A later retry created the function successfully. Node 20 was replaced with Node 22 because the live deploy check reported deprecation and decommissioning on 30 October 2026; the function logic and dependency versions were retained. The Node 22 module loads and passes its syntax check.

The CLI ended with a cleanup-policy warning **after successful function creation**. Artifact Registry has no automatic image cleanup policy. A proposed seven-day cleanup policy was blocked by automatic approval review because future image deletion was not explicitly authorized. No cleanup policy was applied.

## Code-join compatibility issue

The original main commit `f0972e34163c253dead820e8ebc97955cc6034c6` creates an immediately active membership when joining by code. Deployed rules deliberately require admin approval. That original app therefore shows the generic join failure. The corrected app creates a pending request and exposes approve/reject controls to the organization admin.

The rules were deployed before the matching app change reached GitHub. The user reproduced the incompatibility using a fresh checkout of the original main. The fix must reach main and a new app build must be installed; re-installing the unchanged original main does not help. Do not weaken the admin approval rules to accommodate the old app.

The branch `fix/require-member-approval` contains the correction. Relevant local commits: `94cadb0` (approval), `e6a9ef6` (Node 22), `fe2f38c` (complete code-join regression test and clearer errors). The correction is published in PR #11: https://github.com/taaviont-creator/ResponderCrewApp/pull/11. Its Checks tab records validation of the final branch version; merge is permitted only after those checks pass. A bundle of the commits is available in the parent workspace as `RespondCrew-admin-approval.bundle`.

## Validation and remaining release steps

- 38 Firestore emulator tests pass, including code lookup → request transaction → admin listing and approval, and reproduction of the original main's denied activation batch.
- Flutter analyze passes; 29 Flutter tests pass.
- Functions dependencies install, JavaScript syntax passes and the module loads under Node 22. The lint script is a placeholder. Dependency installation reports 12 moderate findings; no automatic dependency upgrades were applied.
- Existing main PR CI #47 was green, including Android build. GitHub CI for the corrected branch is tracked in PR #11; consult its final Checks results for Android build verification. A local Android APK build could not be completed in this environment, so no new APK is claimed as verified.
- Release gate: successful PR #11 CI and merge of the corrected app into main. Build/install that version and run `android-final-device-checklist.md`, including approval, organization switching, readiness/absence, foreground/background/locked-screen alarm, exact callout navigation, response, GPS/wakelock, dialer and persistent login.

## Known major missing feature

Automatic invitation email and new-organization email to the platform admin still need an email service / SMTP / API secret, integration and a delivery test. They are separate from the deployed alarm function.
