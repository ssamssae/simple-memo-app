import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
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
    return strings.minilmInstallFailedGeneric;
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
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _subtitle(context, state),
                style: const TextStyle(color: Color(0xFF9A9AA2)),
              ),
              trailing: _trailing(context, state),
              onTap: switch (state) {
                MiniLmModelState.absent => () => _confirmInstall(context),
                MiniLmModelState.error => () => _confirmInstall(context),
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
    _ => AppStrings.of(context).miniLmInstallFailed,
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
        icon: const Icon(Icons.delete_outline, color: Color(0xFF9A9AA2)),
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
