# First availability in a newly approved organization

AvailabilityService first reads availability/uid_org in a transaction, then writes status and a notification atomically. The old read rule dereferenced resource.data even when the document did not exist, so first-time saves failed with permission-denied.

A get-only rule now permits the missing-document read when the matching membership document belongs to the caller, has consistent organization references, matches the canonical uid_org identifier and is active. Existing records and collection queries retain their original authorization; writes and notifications are unchanged.

Regression: the real first-status transaction fails against the previous rules and succeeds after the fix. All 46 emulator tests pass, including denials for other users, other organizations, removed memberships and anonymous callers. No production member/status records were modified. This is a rules-only fix and requires no app update.
