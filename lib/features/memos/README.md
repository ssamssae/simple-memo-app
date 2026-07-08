# Memos Domain

The `memos` domain owns memo list, memo editing, search, trash, backup/restore
entry points, and memo-specific persistence behavior.

This is a pilot folder for new memo-related features. Existing memo code remains
in the current top-level folders until a focused migration task is approved.

Use this domain for new work when:

- The feature is visible mainly in memo list/edit/search/trash flows.
- The logic depends on `Memo` behavior or memo ordering.
- The UI is not reusable outside memo workflows.

Keep outside this domain when:

- The component is app-wide navigation, monetization, policy, settings, or version display.
- The service is a shared platform adapter used by multiple future domains.
- The change only patches an existing legacy file without adding a new feature surface.
