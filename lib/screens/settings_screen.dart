import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ads_service.dart';
import '../services/app_review_service.dart';
import '../services/remove_ads_purchase.dart';
import '../services/settings_service.dart';
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

  Future<void> _sendFeedback() async {
    final info = await PackageInfo.fromPlatform();
    final subject = Uri.encodeComponent('[메모요 피드백] v${info.version}+${info.buildNumber}');
    final body = Uri.encodeComponent(
      '\n\n\n──────────\n앱: 메모요 ${info.version}+${info.buildNumber}\n(위에 피드백을 적어주세요)',
    );
    final uri = Uri.parse(
      'mailto:minusbetastudio@gmail.com?subject=$subject&body=$body',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 열 수 없습니다')),
      );
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
            ValueListenableBuilder<double>(
              valueListenable: SettingsService.instance.fontScale,
              builder: (context, scale, _) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_size, color: Colors.white),
                          const SizedBox(width: 32),
                          const Expanded(
                            child: Text(
                              '글자 크기',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          Text(
                            '${(scale * 100).round()}%',
                            style: const TextStyle(color: Color(0xFF9A9AA2)),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: 2, bottom: 2),
                        child: Text(
                          '메모 본문이 이 크기로 보여요',
                          style: TextStyle(
                            color: const Color(0xFFECECEC),
                            fontSize: 16 * scale,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('가',
                              style: TextStyle(
                                  color: Color(0xFF9A9AA2), fontSize: 13)),
                          Expanded(
                            child: Slider(
                              value: scale,
                              min: SettingsService.minFontScale,
                              max: SettingsService.maxFontScale,
                              divisions: 8,
                              activeColor: const Color(0xFF7C5CFF),
                              label: '${(scale * 100).round()}%',
                              onChanged: (v) =>
                                  SettingsService.instance.fontScale.value = v,
                              onChangeEnd: (v) =>
                                  SettingsService.instance.setFontScale(v),
                            ),
                          ),
                          const Text('가',
                              style: TextStyle(
                                  color: Color(0xFF9A9AA2), fontSize: 22)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
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
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.feedback_outlined,
                color: Colors.white,
              ),
              title: const Text(
                '피드백 보내기',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _sendFeedback,
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
