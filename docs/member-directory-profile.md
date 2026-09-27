# Member directory and own profile

Members now opens for active organization members. Search, qualification filter and name/admin sorting operate on shared membership data; cards show actual availability and a clear own-member marker. Phone/SMS use the existing authenticated same-organization callable. Ordinary members do not fetch other users' private user documents. Pending requests, invitations, roles and qualification management remain admin-only.

Selecting yourself routes to the same live SelfProfileScreen as the menu. Name/phone editing is the primary action at the top, with validation and retry feedback. The editor owns its controllers until disposal. Role and qualification management is grouped in the profile; self role changes remain unavailable. Equipment, certificates and participation are separate expandable sections with own-screen shortcuts. Existing profile privacy checks remain in place; failed detail reads show an error rather than empty data.

Directory CSV copies only the currently filtered shared fields (name, role, qualification, availability) to the clipboard and neutralizes spreadsheet formulas. Certificate access opens the existing permission-scoped screen. No historical hours or tenure counters are invented.

Validation: 57 Flutter tests pass, including own-profile callback, peer contact identity, filtering, 320px/large-text layout, safe CSV and profile save validation/failure/retry. Flutter analyze clean. Visual review uses real directory widgets with fixture data. Device acceptance: normal member and admin open self from Members, update name/phone and verify directory/home; open another member; verify restricted admin controls and phone/SMS; open each profile detail section.
