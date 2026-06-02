import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('설정', style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            _SettingsTile(
              icon: Icons.article_outlined,
              title: '이용약관',
              subtitle: '메모요 이용 조건을 확인합니다',
              onTap: () => _openLegalDocument(
                context,
                title: '이용약관',
                assetPath: 'assets/legal/terms_ko.md',
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: '개인정보처리방침',
              subtitle: '개인정보 처리 기준을 확인합니다',
              onTap: () => _openLegalDocument(
                context,
                title: '개인정보처리방침',
                assetPath: 'assets/legal/privacy_policy_ko.md',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLegalDocument(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(title: title, assetPath: assetPath),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.amber),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.amber),
      onTap: onTap,
    );
  }
}
