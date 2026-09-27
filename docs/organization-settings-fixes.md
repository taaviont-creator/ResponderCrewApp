# Organization settings fixes

Minimum crew editing now uses a stateful dialog that owns its controller until the route is disposed. This avoids disposing a focused text controller while the dialog exit transition is still running. Save returns the validated integer; cancel returns no value.

Member permissions subscribe to the organization document inside the settings route. Each change patches only its own field plus audit metadata, preventing stale values in the original home route from overwriting other toggles. Writes disable controls until resolved; failures remain visible and allow retry. Existing Firestore admin authorization applies.

The organization chooser includes pending memberships alongside active memberships. A pending organization displays its approval status and cannot become active. Active organization resolution still uses only active memberships. Organization creation continues to require platform approval.

Validation: 50 Flutter tests, including focused dialog save/cancel/reopen, live permission changes and failure recovery. Physical-device acceptance: save minimum crew with keyboard open; toggle all three permissions without leaving settings; create a second organization, see its pending status, approve through platform administration, then switch into it.
