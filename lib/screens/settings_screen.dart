import 'package:flutter/material.dart';

import '../services/app_review_service.dart';
import '../widgets/version_footer.dart';
import 'backup_restore_screen.dart';
import 'policy_screen.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.openReviewListing});

  final Future<AppReviewListingResult> Function()? openReviewListing;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppReviewService _appReviewService = AppReviewService();
  bool _isOpeningReviewListing = false;

  Future<void> _openReviewListing() async {
    if (_isOpeningReviewListing) return;

    setState(() {
      _isOpeningReviewListing = true;
    });

    final result =
        await (widget.openReviewListing ??
            _appReviewService.openReviewListing)();

    if (!mounted) return;
    setState(() {
      _isOpeningReviewListing = false;
    });

    if (result == AppReviewListingResult.unavailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스토어를 열 수 없습니다')));
    }
  }

  void _openPolicy(String title, String assetPath) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(title: title, assetPath: assetPath),
      ),
    );
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TrashScreen()),
    );
  }

  void _openBackupRestore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BackupRestoreScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: VersionFooter()),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('설정', style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.star_rate_outlined,
                color: Colors.amber,
              ),
              title: const Text(
                '앱 평가하기',
                style: TextStyle(color: Colors.white),
              ),
              trailing: _isOpeningReviewListing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.amber),
              onTap: _isOpeningReviewListing ? null : _openReviewListing,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.backup_outlined,
                color: Colors.amber,
              ),
              title: const Text(
                '백업 & 복원',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.amber),
              onTap: _openBackupRestore,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.amber,
              ),
              title: const Text(
                '휴지통',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.amber),
              onTap: _openTrash,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.description_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                '이용약관',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () => _openPolicy(
                '이용약관',
                'docs/legal/terms-of-service.md',
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                '개인정보처리방침',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () => _openPolicy(
                '개인정보처리방침',
                'docs/legal/privacy-policy.md',
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5),
          ],
        ),
      ),
    );
  }
}
