import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mini_lm_model_controller.dart';

class MiniLmModelSettingsTile extends StatelessWidget {
  const MiniLmModelSettingsTile({super.key, required this.manager});

  final MiniLmModelManager manager;

  @override
  Widget build(BuildContext context) {
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
              title: const Text(
                '기기 내 뜻 검색 모델',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _subtitle(state),
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
                child: LinearProgressIndicator(value: manager.progress),
              ),
          ],
        );
      },
    );
  }

  String _subtitle(MiniLmModelState state) => switch (state) {
    MiniLmModelState.checking => '설치 상태 확인 중',
    MiniLmModelState.unsupported => '이 기기에서는 Gemini 검색을 사용합니다',
    MiniLmModelState.absent => '약 124MB · Wi-Fi 권장 · Apache-2.0',
    MiniLmModelState.installing =>
      '다운로드 중 ${(manager.progress * 100).round()}%',
    MiniLmModelState.ready => '설치됨 · 오프라인 검색 가능',
    MiniLmModelState.error => _errorMessage(manager.errorCode),
  };

  String _errorMessage(String? code) => switch (code) {
    'MEMOYO_MINILM_INSUFFICIENT_SPACE' => '저장 공간이 부족합니다 · 다시 시도',
    'MEMOYO_MINILM_HASH_MISMATCH' ||
    'MEMOYO_MINILM_MANIFEST_INVALID' => '모델 검증 실패 · 다시 시도',
    _ => '설치 실패 · 다시 시도',
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
        tooltip: '모델 삭제',
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
        title: const Text('뜻 검색 모델 설치'),
        content: const Text(
          'MiniLM 모델과 토크나이저 약 124MB를 다운로드합니다. '
          'Wi-Fi 사용을 권장하며 설정에서 언제든 삭제할 수 있습니다. '
          '파일은 앱에 고정된 SHA-256 검증을 통과해야 설치됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('minilm-install-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('설치'),
          ),
        ],
      ),
    );
    if (confirmed == true) unawaited(manager.install());
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('뜻 검색 모델 삭제'),
        content: const Text('저장된 모델 파일을 삭제합니다. 기존 메모는 삭제되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('minilm-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) unawaited(manager.delete());
  }
}
