# Home absence planning

Home personal status includes a shortcut that opens the existing one-off absence form directly. The preview combines future one-off periods and weekly occurrences, sorts by start, removes identical ranges and shows at most two. It excludes cancelled, ongoing/past and other-user periods and refreshes with time and existing Firestore streams.

The readiness response-delay control retains +15/+30/+60 minutes. Its optional note editor/save action is removed; existing stored notes are preserved by that screen. Planning notes are unchanged. The planning dialog controller is disposed after the route exit completes.

Validation: 53 Flutter tests including upcoming filtering, weekly recurrence, deduplication and shortcut callback. Analyze clean. Device acceptance: tap shortcut, save a future period, return home and verify preview; cancel the period and verify removal; change delay without a note field.
