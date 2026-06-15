import 'package:flutter/material.dart';

import '../services/ads_service.dart';
import '../services/app_review_service.dart';
import '../services/remove_ads_purchase.dart';
import '../widgets/version_footer.dart';
import 'backup_restore_screen.dart';
import 'policy_screen.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.openReviewListing,
    this.embedded = false,
  });

  final Future<AppReviewListingResult> Function()? openReviewListing;

  /// HomeShell 바텀바의 탭으로 임베드된 경우 true — 뒤로가기 버튼을 숨기고
  /// 버전 풋터를 바텀바 슬롯 대신 본문 하단에 렌더한다.
  final bool embedded;

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

  Future<void> _buyRemoveAds() async {
    final ok = await RemoveAdsPurchase.instance.buy();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금은 상품을 준비 중이에요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    await RemoveAdsPurchase.instance.restore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 내역을 복원하고 있어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: !widget.embedded,
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
                color: Colors.white,
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
                  : const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _isOpeningReviewListing ? null : _openReviewListing,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.removeAds,
              builder: (context, removed, _) {
                if (removed) {
                  return const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    leading: Icon(Icons.check_circle_outline,
                        color: Color(0xFF7C5CFF)),
                    title: Text('광고 제거됨',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text('이용해 주셔서 감사합니다',
                        style: TextStyle(color: Color(0xFF9A9AA2))),
                  );
                }
                final available = RemoveAdsPurchase.instance.available;
                final price = RemoveAdsPurchase.instance.price;
                return Column(
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: const Icon(Icons.block_outlined,
                          color: Color(0xFF7C5CFF)),
                      title: const Text('광고 제거',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        available
                            ? (price ?? '한 번 결제로 배너 광고 제거')
                            : '상품 준비중',
                        style: const TextStyle(color: Color(0xFF9A9AA2)),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFF7C5CFF)),
                      onTap: _buyRemoveAds,
                    ),
                    const Divider(height: 0.5, thickness: 0.5),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: const Icon(Icons.restore,
                          color: Color(0xFF9A9AA2)),
                      title: const Text('구매 복원',
                          style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFF9A9AA2)),
                      onTap: _restorePurchases,
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.backup_outlined,
                color: Colors.white,
              ),
              title: const Text(
                '백업 & 복원',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _openBackupRestore,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.white,
              ),
              title: const Text(
                '휴지통',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
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
            const SizedBox(height: 24),
            const SafeArea(top: false, child: VersionFooter()),
          ],
        ),
      ),
    );
  }
}
