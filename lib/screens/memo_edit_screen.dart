import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../models/memo.dart';
import '../services/settings_service.dart';
import '../utils/app_palette.dart';
import '../l10n/app_strings.dart';
import '../features/memos/services/attachment_service.dart';
import '../features/memos/services/attachment_store.dart';
import '../features/memos/widgets/attachment_strip.dart';
import '../features/memos/widgets/attachment_viewer.dart';

class MemoEditScreen extends StatefulWidget {
  final Memo? memo;
  final ValueChanged<Memo>? onSave;
  // 테스트 주입용. null 이면 AttachmentService.production() 을 첫 사용 시 조립한다.
  final AttachmentService? attachmentService;

  const MemoEditScreen({
    super.key,
    this.memo,
    this.onSave,
    this.attachmentService,
  });

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late final TextEditingController _contentController;
  final UndoHistoryController _undoController = UndoHistoryController();
  final ScrollController _contentScrollController = ScrollController();
  // 사진 피커/카메라에서 돌아온 뒤 키보드를 다시 올리기 위한 본문 포커스 핸들
  // (아니키 S24 실기기 피드백 2026-08-30 01:15 「사진 첨부하고 키보드가 바로
  // 나오지 않는 이슈」). 피커 액티비티가 IME 를 내리지만 포커스는 남아 있어
  // requestFocus 만으론 no-op — unfocus 후 다음 프레임에 다시 잡는다.
  final FocusNode _contentFocusNode = FocusNode();
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _shakeDialogOpen = false;
  bool _photoSheetOpen = false;
  bool _isEditing = false;
  bool _popHandled = false;
  Offset? _lastTouchPosition;
  bool _isClampingSelection = false;

  // 첨부 사진 — 화면에 보이는 현재 목록 + 저장/취소 때 확정할 대기 목록 (spec §3.4).
  late final List<String> _imageFiles;
  final List<String> _pendingAdded = [];
  final List<String> _pendingRemoved = [];
  AttachmentService? _defaultService;

  AttachmentService get _attachments =>
      widget.attachmentService ??
      (_defaultService ??= AttachmentService.production());

  AttachmentStore? get _store =>
      widget.attachmentService?.store ?? AttachmentStore.maybeInstance;

  static const double _shakeThreshold = 18.0;
  static const Duration _shakeCooldown = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.memo != null;
    _imageFiles = List.of(widget.memo?.imageFiles ?? const <String>[]);
    _contentController = TextEditingController(
      text: widget.memo?.content ?? '',
    );
    _contentController.addListener(_clampSelectionTrailingNewline);
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 60),
      ).listen(_onAccel);
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _contentController.removeListener(_clampSelectionTrailingNewline);
    _contentController.dispose();
    _contentScrollController.dispose();
    _contentFocusNode.dispose();
    _undoController.dispose();
    super.dispose();
  }

  // 선택 양 끝이 "라인 끝의 공백/개행" 영역에 걸쳐 있으면 실제 글자 뒤로
  // 하이라이트가 뻗어 보임. 사용자는 마지막 글자에서 멈추기를 원하므로,
  // 공백(space/tab/CR)과 개행(LF)을 선택 양 끝에서 걷어냄. 단 공백은
  // 바로 뒤가 개행/문서끝 일 때만 (= 실제 라인 끝의 잔여 공백일 때만)
  // 잘라서, 문장 중간의 공백은 건드리지 않음.
  void _clampSelectionTrailingNewline() {
    if (_isClampingSelection) return;
    final v = _contentController.value;
    final sel = v.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final text = v.text;
    final len = text.length;

    bool isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0D;

    int trimEnd(int end, int lowerBound) {
      while (end > lowerBound && end > 0) {
        final c = text.codeUnitAt(end - 1);
        if (c == 0x0A) {
          end--;
          continue;
        }
        if (isWs(c)) {
          // 공백은 "선택 끝부터 다음 개행/문서끝까지 모두 공백인 경우"만 잘라냄.
          // (라인 중간의 공백은 건드리지 않음)
          var peek = end;
          var allWsToLineEnd = true;
          while (peek < len) {
            final pc = text.codeUnitAt(peek);
            if (pc == 0x0A) break;
            if (!isWs(pc)) {
              allWsToLineEnd = false;
              break;
            }
            peek++;
          }
          if (allWsToLineEnd) {
            end--;
            continue;
          }
        }
        break;
      }
      return end;
    }

    final base = sel.baseOffset;
    final ext = sel.extentOffset;
    int newBase = base;
    int newExt = ext;
    if (ext > base) {
      newExt = trimEnd(ext, base);
    } else if (base > ext) {
      newBase = trimEnd(base, ext);
    }
    // T-260729-026: 선택이 통째로 접히면 clamp 를 포기한다.
    // 이 clamp 의 목적은 "글자 뒤로 하이라이트가 뻗어 보이는 것"을 막는 화면 보정이지
    // 선택을 없애는 것이 아니다. 그런데 선택이 개행·라인끝 공백으로만 이루어져 있으면
    // trimEnd 가 lowerBound 까지 다 걷어내 선택이 0폭이 된다. 그 상태에서 삭제하면
    // 지우려던 빈 줄은 그대로 남고 접힌 자리 **앞 글자**가 지워진다 — 아니키 실기기
    // 제보("줄바꿈 한번 지우면 두번 연속 안 지워짐")의 실체가 이것이다.
    // 사용자가 빈 줄만 골라 잡은 것은 의도된 선택이므로 보정 대상이 아니다.
    if (newBase == newExt) return;
    if (newBase == base && newExt == ext) return;
    _isClampingSelection = true;
    _contentController.value = v.copyWith(
      selection: TextSelection(baseOffset: newBase, extentOffset: newExt),
    );
    _isClampingSelection = false;
  }

  void _onAccel(AccelerometerEvent e) {
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final netForce = (magnitude - 9.8).abs();
    if (netForce < _shakeThreshold) return;
    final now = DateTime.now();
    if (now.difference(_lastShakeAt) < _shakeCooldown) return;
    _lastShakeAt = now;
    _promptUndoRedo();
  }

  Future<void> _promptUndoRedo() async {
    if (!mounted || _shakeDialogOpen) return;
    final value = _undoController.value;
    if (!value.canUndo && !value.canRedo) return;
    _shakeDialogOpen = true;
    final showRedoOnly = value.canRedo;
    try {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(
            showRedoOnly
                ? AppStrings.of(context).redo
                : AppStrings.of(context).undoAction,
          ),
          content: Text(AppStrings.of(context).whichAction),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.of(context).cancel),
            ),
            if (showRedoOnly)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _undoController.redo();
                },
                child: Text(AppStrings.of(context).redo),
              )
            else if (value.canUndo)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _undoController.undo();
                },
                child: Text(AppStrings.of(context).undoAction),
              ),
          ],
        ),
      );
    } finally {
      _shakeDialogOpen = false;
    }
  }

  // 라인 끝 잔여 공백(space/tab/CR)은 보이지 않는데도 탭 커서가 그 "중간"에
  // 꽂혀, 지워도 오른쪽 잔여가 남아 재진입마다 부활하는 것처럼 보인다
  // (T-260718-021 실기기 영상 판독). 저장 시 라인별로 걷어낸다 — 문장 중간
  // 공백과 라인 앞 들여쓰기는 보존 (_clampSelectionTrailingNewline 철학과 동일).
  String _normalizeContent(String raw) {
    return raw.split('\n').map((line) => line.trimRight()).join('\n').trim();
  }

  Memo? _buildMemo() {
    final content = _normalizeContent(_contentController.text);
    final images = List<String>.unmodifiable(_imageFiles);
    // 본문이 비어도 사진이 있으면 저장 대상 (사진만 있는 메모 허용, 제목은 untitledMemo 폴백).
    if (content.isEmpty && images.isEmpty) return null;

    if (_isEditing && widget.memo != null) {
      return widget.memo!.copyWith(
        content: content,
        updatedAt: DateTime.now(),
        imageFiles: images,
      );
    } else {
      return Memo.create(content: content, imageFiles: images);
    }
  }

  // 저장 확정 뒤: 이번 세션에서 뺀 기존 파일을 실제로 지운다.
  void _commitPendingRemovals() {
    if (_pendingRemoved.isEmpty) return;
    final removed = List<String>.of(_pendingRemoved);
    _pendingRemoved.clear();
    unawaited(_store?.delete(removed) ?? Future<void>.value());
  }

  // 미저장 이탈: 이번 세션에서 추가한 파일을 지운다 (기존 파일은 손대지 않음).
  void _discardPendingAdded() {
    if (_pendingAdded.isEmpty) return;
    final added = List<String>.of(_pendingAdded);
    _pendingAdded.clear();
    _imageFiles.removeWhere(added.contains);
    unawaited(_store?.delete(added) ?? Future<void>.value());
  }

  void _dispatchSave() {
    final memo = _buildMemo();
    if (memo != null) {
      widget.onSave?.call(memo);
      _commitPendingRemovals();
      // 저장된 메모가 참조하는 파일 — 이후 취소가 지우면 안 된다.
      _pendingAdded.clear();
    }
  }

  void _saveAndPop() {
    _popHandled = true;
    _dispatchSave();
    Navigator.pop(context);
  }

  void _saveMemo() {
    final memo = _buildMemo();
    if (memo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).enterContent)),
      );
      return;
    }
    _popHandled = true;
    widget.onSave?.call(memo);
    _commitPendingRemovals();
    // 저장된 메모가 참조하는 파일 — 이후 취소가 지우면 안 된다.
    _pendingAdded.clear();
    Navigator.pop(context);
  }

  Rect? _shareOriginRect(BuildContext shareContext) {
    final box = shareContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareMemo(BuildContext shareContext) async {
    final memo = _buildMemo();
    if (memo == null) {
      _snack(AppStrings.of(context).nothingToShare);
      return;
    }
    try {
      final store = _store;
      final files = <XFile>[
        if (store != null)
          for (final name in memo.imageFiles)
            if (store.fileFor(name).existsSync())
              XFile(store.fileFor(name).path, mimeType: 'image/jpeg'),
      ];
      if (files.isEmpty && memo.content.isEmpty) {
        // 사진만 있는 메모인데 파일이 디스크에 없다(백업 복원 등) — 공유할 게 없다.
        // Share.share('') 는 share_plus 의 빈 문자열 assert 를 때려 "공유 실패"로
        // 오분류되므로, 그 경로를 타기 전에 여기서 막는다.
        _snack(AppStrings.of(context).nothingToShare);
        return;
      }
      if (files.isEmpty) {
        await Share.share(
          memo.content,
          subject: memo.title,
          sharePositionOrigin: _shareOriginRect(shareContext),
        );
      } else {
        await Share.shareXFiles(
          files,
          text: memo.content.isEmpty ? null : memo.content,
          subject: memo.title,
          sharePositionOrigin: _shareOriginRect(shareContext),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _snack(AppStrings.of(context).shareFailed(e));
    }
  }

  Future<void> _cancelEdit() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(AppStrings.of(context).discardConfirmTitle),
        content: Text(AppStrings.of(context).discardConfirmBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(context).keepEditing),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.of(context).cancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _discardPendingAdded();
    _popHandled = true;
    Navigator.pop(context);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhoto() async {
    final strings = AppStrings.of(context);
    if (_imageFiles.length >= AttachmentService.maxImages) {
      _snack(strings.photoLimitReached);
      return;
    }
    // 더블탭 등으로 시트가 겹쳐 뜨는 것을 막는다 (_shakeDialogOpen 과 같은 패턴).
    if (_photoSheetOpen) return;
    _photoSheetOpen = true;
    final _PhotoSource? source;
    try {
      // 붙여넣기는 항상 노출 — 미리 클립보드를 읽어 활성/비활성을 정하면
      // iOS 「붙여넣기 허용?」 시스템 프롬프트가 두 번 뜬다.
      source = await showCupertinoModalPopup<_PhotoSource>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, _PhotoSource.gallery),
              child: Text(strings.fromGallery),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, _PhotoSource.camera),
              child: Text(strings.fromCamera),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, _PhotoSource.clipboard),
              child: Text(strings.pasteImage),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
        ),
      );
    } finally {
      _photoSheetOpen = false;
    }
    if (source == null || !mounted) return;

    final count = _imageFiles.length;
    AttachResult result;
    try {
      result = switch (source) {
        _PhotoSource.gallery => await _attachments.pickFromGallery(count),
        _PhotoSource.camera => await _attachments.takePhoto(count),
        _PhotoSource.clipboard => await _attachments.pasteFromClipboard(count),
      };
    } catch (e) {
      // AttachmentService.production() 이 스토어 미초기화로 던지는 경우 등.
      debugPrint('[MemoEditScreen._addPhoto] $e');
      result = AttachFailed(e);
    }
    if (!mounted) return;

    switch (result) {
      case AttachOk(:final fileName):
        setState(() {
          _imageFiles.add(fileName);
          _pendingAdded.add(fileName);
        });
      case AttachOkMany(:final fileNames, :final truncated, :final failed):
        setState(() {
          _imageFiles.addAll(fileNames);
          _pendingAdded.addAll(fileNames);
        });
        // 피커가 limit 을 못 지켜 뒤를 잘랐으면 「최대 10장」 안내, 일부 실패면 실패 안내.
        if (truncated) {
          _snack(strings.photoLimitReached);
        } else if (failed > 0) {
          _snack(strings.photoAttachFailed);
        }
      case AttachCancelled():
        break;
      case AttachNoImage():
        _snack(strings.noImageInClipboard);
      case AttachLimit():
        _snack(strings.photoLimitReached);
      case AttachPermissionDenied():
        _snack(strings.cameraPermissionDenied);
      case AttachFailed():
        _snack(strings.photoAttachFailed);
    }
    // 취소든 성공이든 피커에서 돌아오면 바로 이어서 타이핑할 수 있게 키보드 복귀.
    _refocusEditor();
  }

  void _refocusEditor() {
    if (!mounted) return;
    _contentFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocusNode.requestFocus();
    });
  }

  // 이번 세션에서 추가한 파일은 어느 메모도 참조하지 않으므로 즉시 삭제,
  // 기존 파일은 저장 시점까지 보류 (취소하면 복귀).
  void _removePhoto(String fileName) {
    if (!_imageFiles.contains(fileName)) return;
    setState(() {
      _imageFiles.remove(fileName);
      if (_pendingAdded.remove(fileName)) {
        unawaited(_store?.delete([fileName]) ?? Future<void>.value());
      } else {
        _pendingRemoved.add(fileName);
      }
    });
  }

  Future<void> _confirmRemovePhoto(int index) async {
    if (index < 0 || index >= _imageFiles.length) return;
    final fileName = _imageFiles[index];
    final strings = AppStrings.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(strings.deletePhotoConfirmTitle),
        content: Text(strings.deletePhotoConfirmBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deletePhotoConfirmTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _removePhoto(fileName);
  }

  void _openViewer(int index) {
    if (_imageFiles.isEmpty || index < 0 || index >= _imageFiles.length) return;
    AttachmentViewer.show(
      context,
      fileNames: List.of(_imageFiles),
      initialIndex: index,
      onDelete: _removePhoto,
    );
  }

  Future<void> _handlePasteWithNewline(
    EditableTextState editableTextState,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty) {
      final insertText = text.endsWith('\n') ? text : '$text\n';
      final value = _contentController.value;
      final sel = value.selection;
      final start = sel.isValid ? sel.start : value.text.length;
      final end = sel.isValid ? sel.end : value.text.length;
      final newText = value.text.replaceRange(start, end, insertText);
      _contentController.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + insertText.length),
        composing: TextRange.empty,
      );
    }
    editableTextState.hideToolbar();
  }

  void _handleContentPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_contentScrollController.hasClients) {
      return;
    }
    final position = _contentScrollController.position;
    final target = (position.pixels + event.scrollDelta.dy)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) return;
    position.jumpTo(target);
  }

  Widget _pillButton({
    String? label,
    IconData? icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final hasLabel = label != null && label.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: 16, color: color),
            if (hasLabel) ...[
              if (icon != null) const SizedBox(width: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEditing
        ? AppStrings.of(context).editMemoTitle
        : AppStrings.of(context).newMemoTitle;
    final palette = AppPalette.of(context);
    final appBarTheme = Theme.of(context).appBarTheme;
    final baseTitleStyle =
        appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
          color: appBarTheme.foregroundColor ?? palette.textPrimary,
        );
    // 헤더·본문·컨트롤이 한 팔레트를 함께 따라간다 (T-260806-011).
    // 종전에는 본문만 다크로 박혀 있고 컨트롤이 흰색 하드코딩이라, 헤더 배경을
    // 테마에 맡기면 라이트에서 흰 글자가 밝은 헤더에 묻혔다. 그래서 헤더까지
    // 다크로 고정해 뒀는데(T-260720-024), 이제 색이 전부 팔레트를 거치므로
    // 그 고정이 필요 없어졌다.
    final titleStyle = baseTitleStyle?.copyWith(
      fontSize: 17,
      color: palette.textPrimary,
    );
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        if (_popHandled) return;
        _dispatchSave();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leadingWidth: 192,
          title: null,
          flexibleSpace: SafeArea(
            child: IgnorePointer(
              child: Container(
                height: kToolbarHeight,
                alignment: Alignment.center,
                child: Text(titleText, style: titleStyle),
              ),
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pillButton(
                  label: AppStrings.of(context).back,
                  color: palette.textPrimary,
                  onTap: _saveAndPop,
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 6),
                  _pillButton(
                    label: AppStrings.of(context).cancel,
                    color: palette.danger,
                    onTap: _cancelEdit,
                  ),
                ],
                // 새 메모(아직 저장 전)에는 공유할 내용이 없어 공유 버튼 숨김 (아니키 요청)
                if (widget.memo != null) ...[
                  const SizedBox(width: 4),
                  Builder(
                    builder: (shareContext) => IconButton(
                      icon: const Icon(Icons.share, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      color: palette.textPrimary,
                      tooltip: AppStrings.of(context).share,
                      onPressed: () => _shareMemo(shareContext),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undoController,
              builder: (context, value, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      color: value.canUndo
                          ? palette.textPrimary
                          : palette.textPrimary.withValues(alpha: 0.25),
                      onPressed: value.canUndo ? _undoController.undo : null,
                      tooltip: AppStrings.of(context).undoAction,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.redo, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      color: value.canRedo
                          ? palette.textPrimary
                          : palette.textPrimary.withValues(alpha: 0.25),
                      onPressed: value.canRedo ? _undoController.redo : null,
                      tooltip: AppStrings.of(context).redo,
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 0),
              child: _pillButton(
                label: AppStrings.of(context).save,
                color: palette.textPrimary,
                onTap: _saveMemo,
              ),
            ),
          ],
        ),
        // 사진 추가 = 오른쪽 아래 떠 있는 작은 버튼. Scaffold 의 FAB 는 키보드 위로
        // 따라 올라온다(bottomNavigationBar 는 키보드 뒤에 깔려 안 보였다 — 아니키
        // 실기기 스크린샷 2026-08-29 21:26, 「떠 있는 float button 이 좋아보이는데」).
        // 원래 AppBar actions 에 있었는데 402pt 폭에서 뒤로·취소·공유 + 되돌리기·
        // 다시실행·저장까지 8개가 되자 가운데 제목과 겹쳤다(21:05 스크린샷).
        // 위 바는 PR 이전 배치 그대로 되돌렸다.
        floatingActionButton: FloatingActionButton.small(
          heroTag: null,
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          tooltip: AppStrings.of(context).addPhoto,
          onPressed: _addPhoto,
          child: const Icon(Icons.add_photo_alternate_outlined, size: 22),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 600) {
              _saveAndPop();
            }
          },
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  controller: _contentScrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Listener(
                      onPointerDown: (e) => _lastTouchPosition = e.position,
                      onPointerUp: (e) => _lastTouchPosition = e.position,
                      onPointerSignal: _handleContentPointerSignal,
                      child: ValueListenableBuilder<double>(
                        valueListenable: SettingsService.instance.bodyFontSize,
                        builder: (context, bodyFontSize, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 기존엔 바깥 ConstrainedBox(minHeight: 뷰포트)가 TextField 를 뷰포트
                            // 높이까지 늘려 「본문 아래 빈 곳 탭 → 캐럿」이 됐다. Column 은 자식에
                            // min 0 을 주므로 그 동작이 죽는다 → TextField 에 직접
                            // (뷰포트 − 스트립 높이) minHeight 를 준다. constraints = LayoutBuilder 인자.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0.0,
                                  constraints.maxHeight -
                                      (_imageFiles.isNotEmpty
                                          ? AttachmentStrip.totalHeight
                                          : 0),
                                ),
                              ),
                              child: TextField(
                                controller: _contentController,
                                focusNode: _contentFocusNode,
                                undoController: _undoController,
                                cursorColor: palette.textPrimary,
                                cursorHeight: bodyFontSize,
                                selectionControls:
                                    _largeCupertinoSelectionControls,
                                scrollPhysics:
                                    const NeverScrollableScrollPhysics(),
                                selectionHeightStyle:
                                    ui.BoxHeightStyle.includeLineSpacingMiddle,
                                strutStyle: StrutStyle(
                                  fontSize: bodyFontSize,
                                  height: 1.5,
                                  leading: 0,
                                  forceStrutHeight: true,
                                ),
                                decoration: InputDecoration(
                                  hintText: AppStrings.of(context).contentHint,
                                  hintStyle: TextStyle(
                                    color: palette.textSecondary,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: bodyFontSize,
                                  height: 1.5,
                                  leadingDistribution:
                                      TextLeadingDistribution.even,
                                  letterSpacing: 0.2,
                                  decoration: TextDecoration.none,
                                  decorationColor: Colors.transparent,
                                  decorationThickness: 0,
                                ),
                                maxLines: null,
                                autofocus: !_isEditing,
                                contextMenuBuilder: (context, editableTextState) {
                                  final items =
                                      List<ContextMenuButtonItem>.from(
                                        editableTextState
                                            .contextMenuButtonItems,
                                      );
                                  if (!Platform.isIOS) {
                                    for (var i = 0; i < items.length; i++) {
                                      if (items[i].type ==
                                          ContextMenuButtonType.paste) {
                                        items[i] = ContextMenuButtonItem(
                                          type: ContextMenuButtonType.paste,
                                          onPressed: () =>
                                              _handlePasteWithNewline(
                                                editableTextState,
                                              ),
                                        );
                                      }
                                    }
                                  }
                                  final sel = editableTextState
                                      .textEditingValue
                                      .selection;
                                  final text =
                                      editableTextState.textEditingValue.text;
                                  items.removeWhere(
                                    (item) =>
                                        item.type ==
                                        ContextMenuButtonType.selectAll,
                                  );
                                  final allSelected =
                                      sel.isValid &&
                                      sel.start == 0 &&
                                      sel.end == text.length;
                                  if (text.isNotEmpty && !allSelected) {
                                    final selectAll = ContextMenuButtonItem(
                                      type: ContextMenuButtonType.selectAll,
                                      label: 'Select All',
                                      onPressed: () {
                                        editableTextState.selectAll(
                                          SelectionChangedCause.toolbar,
                                        );
                                      },
                                    );
                                    final pasteIdx = items.indexWhere(
                                      (item) =>
                                          item.type ==
                                          ContextMenuButtonType.paste,
                                    );
                                    if (pasteIdx >= 0) {
                                      items.insert(pasteIdx, selectAll);
                                    } else {
                                      items.add(selectAll);
                                    }
                                  }

                                  var anchors =
                                      editableTextState.contextMenuAnchors;
                                  if (allSelected) {
                                    final s = MediaQuery.of(context).size;
                                    final mid = Offset(
                                      s.width / 2,
                                      s.height / 2,
                                    );
                                    anchors = TextSelectionToolbarAnchors(
                                      primaryAnchor: mid,
                                      secondaryAnchor: mid,
                                    );
                                  } else if (sel.isValid &&
                                      _lastTouchPosition != null) {
                                    anchors = TextSelectionToolbarAnchors(
                                      primaryAnchor: _lastTouchPosition!,
                                      secondaryAnchor: _lastTouchPosition!,
                                    );
                                  }

                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: anchors,
                                    buttonItems: items,
                                  );
                                }, // end contextMenuBuilder
                              ), // end TextField
                            ), // end ConstrainedBox
                            // 사진 0장이면 위젯 자체를 넣지 않는다 → 기존 레이아웃 무변경.
                            if (_imageFiles.isNotEmpty)
                              AttachmentStrip(
                                fileNames: _imageFiles,
                                onTap: _openViewer,
                                onLongPress: _confirmRemovePhoto,
                              ),
                          ],
                        ), // end Column
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeHandlePainter extends CustomPainter {
  const _LargeHandlePainter(this.color, this.radius);
  final Color color;
  final double radius;
  static const double _overlap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const halfStrokeWidth = 1.0;
    final paint = Paint()..color = color;
    final circle = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );
    final line = Rect.fromPoints(
      Offset(radius - halfStrokeWidth, 2 * radius - _overlap),
      Offset(radius + halfStrokeWidth, size.height),
    );
    final path = Path()
      ..addOval(circle)
      ..addRect(line);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LargeHandlePainter oldPainter) =>
      color != oldPainter.color || radius != oldPainter.radius;
}

class _LargeCupertinoSelectionControls extends CupertinoTextSelectionControls {
  static const double _radius = 7.0;
  static const double _overlap = 1.5;

  @override
  Size getHandleSize(double textLineHeight) {
    return Size(_radius * 2, textLineHeight + _radius * 2 - _overlap);
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final Size desiredSize;
    final Widget handle;
    final Widget customPaint = CustomPaint(
      painter: _LargeHandlePainter(
        CupertinoTheme.of(context).selectionHandleColor,
        _radius,
      ),
    );

    switch (type) {
      case TextSelectionHandleType.left:
        desiredSize = getHandleSize(textLineHeight);
        handle = SizedBox.fromSize(size: desiredSize, child: customPaint);
        return handle;
      case TextSelectionHandleType.right:
        desiredSize = getHandleSize(textLineHeight);
        handle = SizedBox.fromSize(size: desiredSize, child: customPaint);
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(
              desiredSize.width / 2,
              desiredSize.height / 2,
              0,
              1,
            )
            ..rotateZ(math.pi)
            ..translateByDouble(
              -desiredSize.width / 2,
              -desiredSize.height / 2,
              0,
              1,
            ),
          child: handle,
        );
      case TextSelectionHandleType.collapsed:
        return SizedBox.fromSize(size: getHandleSize(textLineHeight));
    }
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    final Size handleSize = getHandleSize(textLineHeight);
    switch (type) {
      case TextSelectionHandleType.left:
        return Offset(handleSize.width / 2, handleSize.height);
      case TextSelectionHandleType.right:
        return Offset(
          handleSize.width / 2,
          handleSize.height - 2 * _radius + _overlap,
        );
      case TextSelectionHandleType.collapsed:
        return Offset(
          handleSize.width / 2,
          textLineHeight + (handleSize.height - textLineHeight) / 2,
        );
    }
  }
}

final _largeCupertinoSelectionControls = _LargeCupertinoSelectionControls();

enum _PhotoSource { gallery, camera, clipboard }
