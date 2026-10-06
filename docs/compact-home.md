# Compact home and organization contacts

The home screen shows the organization switcher, first-name greeting and current organization role, personal availability, then shared effective readiness and duty crew. Planned absence excludes members from the displayed duty crew. Delayed members remain visible with their configured arrival minutes but do not count toward immediate SAR readiness.

Phone/SMS actions request only the phone field through getOrganizationMemberContact in europe-north1. The caller and target must both have active, consistent memberships in the same approved organization. Pending/removed/cross-organization requests are denied. Full user profiles remain private. SMS opens the device composer and never sends automatically.

Validation: Flutter analyze; 47 Flutter tests including 320px/200% text layout, scheduled absence, shared readiness and phone URI handling; 11 Functions tests including contact authorization. Visual review uses real widgets with fixture data.

Android acceptance: switch between two organizations and verify title/role/crew change together; toggle availability and verify both member/admin views; schedule absence; open phone and SMS from a normal active member account; check missing phone feedback. Verify denied access after membership removal. Actual dialer/composer behavior requires a physical device.

Deployment: publish functions:getOrganizationMemberContact before distributing this app version. No Firestore rule widening is required.

## 2026-10-06: dashboard crew pills

Both member and admin dashboards now use the supplied visual reference: a readiness
heading, two compact condition badges, a Details action and wrapping member pills.
On-duty members use green, delayed members use orange with the delay written out;
a missing qualification does not add a noisy empty badge. Member name/profile,
phone and SMS remain separate actions with at least 48px contact targets.
The preview shows up to four members; counts still cover the entire crew. Full
organization readiness retains its existing detailed list. Server statuses,
organization pauses and contact authorization remain unchanged. No schema, Rules,
Functions or APK changes.

Regression coverage: horizontal wrapping, long names on 320px screens at normal
and 200% text scale, separate actions, delayed II-level qualification, authoritative
unknown/delayed status, organization pause and duplicate-contact prevention.
