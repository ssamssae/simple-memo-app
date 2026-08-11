import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../utils/app_palette.dart';
import '../services/mini_lm_model_controller.dart';

class MiniLmModelSettingsTile extends StatefulWidget {
  const MiniLmModelSettingsTile({super.key, required this.manager});

  final MiniLmModelManager manager;

  @override
  State<MiniLmModelSettingsTile> createState() =>
      _MiniLmModelSettingsTileState();
}

class _MiniLmModelSettingsTileState extends State<MiniLmModelSettingsTile> {
  MiniLmModelState? _previousState;

  @override
  void initState() {
    super.initState();
    _previousState = widget.manager.state;
    widget.manager.addListener(_onManagerChanged);
  }

  @override
  void didUpdateWidget(covariant MiniLmModelSettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.manager, widget.manager)) {
      oldWidget.manager.removeListener(_onManagerChanged);
      _previousState = widget.manager.state;
      widget.manager.addListener(_onManagerChanged);
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  // T-260719-018: 설치 시도(installing) 중 실패로 전이하면 즉시 스낵바로 사유 알림.
  // (화면 진입 시 refresh 가 띄우는 error 는 타일 소제목으로만 — 오픈 시 스낵바 스팸 방지.)
  void _onManagerChanged() {
    final next = widget.manager.state;
    final prev = _previousState;
    _previousState = next;
    if (prev == MiniLmModelState.installing &&
        next == MiniLmModelState.error &&
        mounted) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('minilm-install-failed-snackbar'),
            content: Text(_failureReasonText(strings, widget.manager.errorCode)),
            duration: const Duration(seconds: 6),
          ),
        );
    }
  }

  // 실패 사유 3분류 (T-260719-018): 네트워크 중단 / SHA-256 검증 실패 / 저장공간 부족.
  // installer 의 EmbeddingFailure code 체계를 그대로 해석한다 (코드 변경 없음).
  String _failureReasonText(AppStrings strings, String? code) {
    if (code == null) return strings.minilmInstallFailedGeneric;
    if (code == 'MEMOYO_MINILM_INSUFFICIENT_SPACE') {
      return strings.minilmInstallFailedStorage;
    }
    if (code == 'MEMOYO_MINILM_HASH_MISMATCH' ||
        code == 'MEMOYO_MINILM_MANIFEST_INVALID') {
      return strings.minilmInstallFailedVerify;
    }
    if (code.startsWith('MEMOYO_MINILM_HTTP_') ||
        code == 'MEMOYO_MINILM_DOWNLOAD_FAILED' ||
        code == 'MEMOYO_MINILM_DOWNLOAD_INCOMPLETE') {
      return strings.minilmInstallFailedNetwork;
    }
    return _withCode(strings.minilmInstallFailedGeneric, code);
  }

  // T-260730-029: 3분류(네트워크·검증·저장공간) 밖의 실패는 지금까지 「설치 실패 · 다시 시도」
  //   하나로 뭉개져 사용자도 개발자도 원인을 몰랐다. 아니키 기기 실측(2026-07-30 08:53)이
  //   정확히 이 상태였고, 그래서 근인이 STATUS_FAILED·INSTALL_FAILED·LOAD_FAILED·
  //   OUT_OF_MEMORY 중 무엇인지 코드로 좁힐 수 없었다(감사 PR#1409 §4).
  //   → 분류 밖 코드만 화면에 덧붙인다. 한줄일기가 `[#502 upstream_failed]` 로 쓰는 것과 같은 패턴.
  //   3분류 문구는 이미 사유를 말하므로 건드리지 않는다.
  static String _withCode(String base, String? code) {
    if (code == null || code.isEmpty) return base;
    const prefix = 'MEMOYO_MINILM_';
    final short = code.startsWith(prefix) ? code.substring(prefix.length) : code;
    return '$base [#$short]';
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final state = manager.state;
        return Column(
          children: [
            ListTile(
              key: const Key('minilm-model-tile'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.offline_bolt_outlined,
                color: Color(0xFF7C5CFF),
              ),
              title: Text(
                AppStrings.of(context).miniLmTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                _subtitle(context, state),
                style: TextStyle(color: AppPalette.of(context).textSecondary),
              ),
              trailing: _trailing(context, state),
              onTap: switch (state) {
                MiniLmModelState.absent => () => _confirmInstall(context),
                MiniLmModelState.error => () => _confirmInstall(context),
                // T-260811-015: 설치 후에는 탭하면 상세(저장소·리비전·해시)를 편다.
                //   서브타이틀은 모델명·용량·라이선스까지만 담는다.
                MiniLmModelState.ready => () => _showDetails(context),
                _ => null,
              },
            ),
            if (state == MiniLmModelState.installing)
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 0, 16, 10),
                child: LinearProgressIndicator(
                  key: const Key('minilm-install-progress'),
                  // T-260719-018: 첫 청크 수신 전(0%)엔 indeterminate — 탭 직후 즉시 움직임 표시.
                  value: manager.progress == 0 ? null : manager.progress,
                ),
              ),
          ],
        );
      },
    );
  }

  String _subtitle(BuildContext context, MiniLmModelState state) => switch (state) {
    MiniLmModelState.checking => AppStrings.of(context).miniLmChecking,
    MiniLmModelState.unsupported => AppStrings.of(context).miniLmUnsupported,
    MiniLmModelState.absent => AppStrings.of(context).miniLmAbsent,
    MiniLmModelState.installing => widget.manager.progress == 0
        ? AppStrings.of(context).minilmPreparingDownload
        : AppStrings.of(context)
            .miniLmDownloading((widget.manager.progress * 100).round()),
    MiniLmModelState.ready => AppStrings.of(context).miniLmReady,
    MiniLmModelState.error => _errorMessage(context, widget.manager.errorCode),
  };

  String _errorMessage(BuildContext context, String? code) => switch (code) {
    'MEMOYO_MINILM_INSUFFICIENT_SPACE' => AppStrings.of(context).miniLmInsufficientSpace,
    'MEMOYO_MINILM_HASH_MISMATCH' ||
    'MEMOYO_MINILM_MANIFEST_INVALID' => AppStrings.of(context).miniLmManifestInvalid,
    _ when code != null &&
            (code.startsWith('MEMOYO_MINILM_HTTP_') ||
                code == 'MEMOYO_MINILM_DOWNLOAD_FAILED' ||
                code == 'MEMOYO_MINILM_DOWNLOAD_INCOMPLETE') =>
      AppStrings.of(context).minilmInstallFailedNetwork,
    _ => _withCode(AppStrings.of(context).miniLmInstallFailed, code),
  };

  Widget? _trailing(BuildContext context, MiniLmModelState state) {
    return switch (state) {
      MiniLmModelState.checking ||
      MiniLmModelState.installing => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      MiniLmModelState.ready => IconButton(
        key: const Key('minilm-delete-button'),
        tooltip: AppStrings.of(context).miniLmDeleteTooltip,
        icon: Icon(
          Icons.delete_outline,
          color: AppPalette.of(context).textSecondary,
        ),
        onPressed: () => _confirmDelete(context),
      ),
      MiniLmModelState.absent || MiniLmModelState.error => const Icon(
        Icons.download_outlined,
        color: Color(0xFF7C5CFF),
      ),
      MiniLmModelState.unsupported => null,
    };
  }

  Future<void> _confirmInstall(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.of(context).miniLmInstallTitle),
        content: Text(AppStrings.of(context).miniLmInstallBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          FilledButton(
            key: const Key('minilm-install-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.of(context).install),
          ),
        ],
      ),
    );
    if (confirmed == true) unawaited(widget.manager.install());
  }

  // T-260811-015: 읽기 전용 상세. 설치·삭제·검증 어느 로직도 건드리지 않는다.
  Future<void> _showDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('minilm-details-dialog'),
        title: Text(AppStrings.of(context).miniLmDetailsTitle),
        content: SingleChildScrollView(
          child: SelectableText(AppStrings.of(context).miniLmDetailsBody),
        ),
        actions: [
          TextButton(
            key: const Key('minilm-details-close'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.of(context).miniLmDetailsClose),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.of(context).miniLmDeleteTitle),
        content: Text(AppStrings.of(context).miniLmDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          FilledButton(
            key: const Key('minilm-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed == true) unawaited(widget.manager.delete());
  }
}
