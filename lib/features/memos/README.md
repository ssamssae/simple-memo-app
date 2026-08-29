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

## Image attachments (T-260829-022)

- `services/attachment_store.dart` · `attachment_service.dart` · `image_ingest.dart`,
  `widgets/attachment_thumbnail.dart` · `attachment_strip.dart` · `attachment_viewer.dart`.
- Legacy imports: `models/memo.dart` (file-name validation), `l10n/app_strings.dart`,
  `utils/app_palette.dart`. These stay shared — they are app-wide, not memo-owned.
- `services/memo_storage.dart` (legacy) now imports `AttachmentStore` so that the single
  permanent-delete funnel (`deleteForever` / `emptyTrash` / `purgeExpiredTrash`) also removes
  attachment files. That dependency points legacy → domain on purpose: file cleanup must never
  be skipped by a new delete path.
- Test seam: `AttachmentThumbnail.decodeImages` (static, test-only by convention) and
  `MemoListScreenState.resetOrphanSweepForTest()` / `markOrphanSweepDoneForTest()`. Widget tests
  must seed files in `setUp` and wrap real-IO interactions in `tester.runAsync` — real `dart:io`
  awaits inside a `testWidgets` body hang under FakeAsync.
