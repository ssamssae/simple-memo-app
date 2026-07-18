import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mini_lm_model_controller.dart';
import '../../../l10n/app_strings.dart';


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
                child: LinearProgressIndicator(value: manager.progress),
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
    MiniLmModelState.installing =>
      AppStrings.of(context).miniLmDownloading((manager.progress * 100).round()),
    MiniLmModelState.ready => AppStrings.of(context).miniLmReady,
    MiniLmModelState.error => _errorMessage(context, manager.errorCode),
  };

  String _errorMessage(BuildContext context, String? code) => switch (code) {
    'MEMOYO_MINILM_INSUFFICIENT_SPACE' => AppStrings.of(context).miniLmInsufficientSpace,
    'MEMOYO_MINILM_HASH_MISMATCH' ||
    'MEMOYO_MINILM_MANIFEST_INVALID' => AppStrings.of(context).miniLmManifestInvalid,
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
    if (confirmed == true) unawaited(manager.install());
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
    if (confirmed == true) unawaited(manager.delete());
  }
}
