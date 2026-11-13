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
  permanent-delete funnel (`deleteForever` / `emptyTrash`) also removes
  attachment files. That dependency points legacy → domain on purpose: file cleanup must never
  be skipped by a new delete path. Permanent deletion and the cold-start orphan sweep also
  retain files referenced by the last import snapshot, so undo can restore its photos.
- Test seam: `AttachmentThumbnail.decodeImages` (static, test-only by convention) and
  `MemoListScreenState.resetOrphanSweepForTest()` / `markOrphanSweepDoneForTest()`. Widget tests
  must seed files in `setUp` and wrap real-IO interactions in `tester.runAsync` — real `dart:io`
  awaits inside a `testWidgets` body hang under FakeAsync.

## Photo backups (T-260829-024)

- `services/memo_backup_archive.dart` owns the ZIP format (`memos.json` and `attachments/`),
  legacy JSON decoding, CRC/path/reference validation and bounded decompression.
- Legacy `export_import_service.dart` shares that codec between the file picker and Drive.
  Only photos used by winning incoming memos are installed under new UUID names; persistence
  failure removes newly created files and restores the prior memo list and undo snapshot.
- `snapshot_store.dart` exposes photo references for permanent deletion and cold-start cleanup.
  Imported files become eligible for cleanup after undo succeeds or the snapshot is replaced.

## Favorite order (T-261101-034)

- `services/favorite_order.dart` owns favorite toggle ordering. The list has no sort key: the stored
  array order is the manual order (new memos go to the top of the normal group), favorites first.
- Favoriting records the id of the active normal memo directly below it in `Memo.favoriteAnchorId`
  (JSON key `favoriteAnchorId`, written only when set). Unfavoriting puts the memo back right above
  that memo, following the chain when the anchor was favorited later. Missing or purged anchors
  (including memos favorited before this key existed) fall back to the newest-first `createdAt` slot.
- The toggle never changes `updatedAt` — it is the search ranking and backup merge key.

## Checklist lines (T-261110-014)

- `services/checklist_text.dart` reads and edits checklist marks inside `Memo.content`.
  An open item is U+2610 plus a space. A done item is U+2611 plus a space.
- The memo JSON keys, Drive backup, and export archive stay the same. The marks are
  ordinary characters in `content`.
- The editor stores them with the existing trailing-whitespace cleanup, and keeps the
  one prefix space on an otherwise empty checklist line.
- Search, semantic indexing, and speech search keep using the raw memo text.
- The editor measures checklist tap targets again when the window size or the
  system text scale changes. Rotation and split view keep the target on the mark.

## Done checkbox and Done tab (T-261113-024)

- Replaces the separate to-do tab (T-261112-052). Every memo row in the memo list has a
  checkbox on its left (`widgets/memo_done_checkbox.dart`, 44pt tap target). Tapping it shows
  the check and strikethrough at once, waits one second (a second tap cancels), collapses the
  row (`widgets/collapse_out.dart`), and stores `Memo.doneAt` (JSON key `doneAt`, written only
  when set; old JSON reads as not done).
- Done memos stay in the stored array at their position. The memo list hides them, so
  unchecking puts a memo back in its old place. `updatedAt` does not change (same rule as favorites).
- `screens/done_memos_screen.dart` is the 「완료」 bottom tab: done memos newest `doneAt` first,
  uncheck with the same one-second delay, tap to edit, 「완료 비우기」 moves them to the trash
  (`deletedAt`, undo snackbar). A done memo restored from the trash returns to the Done tab.
- List rules live in `services/memo_done_ops.dart`. Both tabs read storage again before a write
  (`MemoStorage.loadMemos(throwOnError: true)`) so a delayed write does not overwrite the other tab.
- `services/todo_memo_migration.dart` converts the old `todos` key once (flag
  `todos_migrated_to_memos_v1`), keeping the todo id, times, and done time. `MemoStorage.loadMemos`
  runs it first, so every screen sees migrated memos. The `todos` key is left untouched.
  Old backups with `todos.json` are converted by `MemoBackupArchive.decode`; exports no longer add it.
- Legacy imports from the Done tab: `screens/memo_edit_screen.dart`, `services/memo_storage.dart`,
  `services/settings_service.dart`. They stay shared — the editor and storage are the memo funnels.
- Search shows done memos with a check mark and strikethrough. The trash screen is unchanged.
