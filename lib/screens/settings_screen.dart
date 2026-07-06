import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/ads_service.dart';
import '../services/app_review_service.dart';
import '../services/remove_ads_purchase.dart';
import '../services/settings_service.dart';
import '../widgets/version_footer.dart';
import 'backup_restore_screen.dart';
import 'help_faq_screen.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).storeUnavailable)),
      );
    }
  }

  Future<void> _sendFeedback() async {
    final strings = AppStrings.of(context);
    final info = await PackageInfo.fromPlatform();
    final subject = Uri.encodeComponent(
      '${strings.feedbackSubject} v${info.version}+${info.buildNumber}',
    );
    final body = Uri.encodeComponent(
      strings.feedbackBody(info.version, info.buildNumber),
    );
    final uri = Uri.parse(
      'mailto:minusbetastudio@gmail.com?subject=$subject&body=$body',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.mailUnavailable)));
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TrashScreen()));
  }

  void _openBackupRestore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BackupRestoreScreen()),
    );
  }

  void _openHelp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HelpFaqScreen()));
  }

  Future<void> _openLanguageMenu() async {
    final strings = AppStrings.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(strings.language), textColor: Colors.white),
            _languageOption(
              sheetContext: sheetContext,
              code: 'ko',
              label: strings.korean,
            ),
            _languageOption(
              sheetContext: sheetContext,
              code: 'en',
              label: strings.english,
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageOption({
    required BuildContext sheetContext,
    required String code,
    required String label,
  }) {
    final selected = SettingsService.instance.languageCode.value == code;
    return ListTile(
      textColor: Colors.white,
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check, color: Color(0xFF7C5CFF))
          : null,
      onTap: () => _selectLanguage(sheetContext, code),
    );
  }

  Future<void> _selectLanguage(BuildContext sheetContext, String code) async {
    final navigator = Navigator.of(sheetContext);
    await SettingsService.instance.setLanguageCode(code);
    if (!mounted) return;
    navigator.pop();
    setState(() {});
  }

  Future<void> _buyRemoveAds() async {
    final ok = await RemoveAdsPurchase.instance.buy();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).productUnavailable)),
      );
    }
  }

  Future<void> _restorePurchases() async {
    await RemoveAdsPurchase.instance.restore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).restoringPurchases)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: !widget.embedded,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(strings.settings, style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            const Divider(height: 0.5, thickness: 0.5),
            ValueListenableBuilder<double>(
              valueListenable: SettingsService.instance.bodyFontSize,
              builder: (context, fontSize, _) {
                final fontSizeLabel = '${fontSize.round()}sp';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_size, color: Colors.white),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Text(
                              strings.fontSize,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Text(
                            fontSizeLabel,
                            style: const TextStyle(color: Color(0xFF9A9AA2)),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 48,
                          top: 2,
                          bottom: 2,
                        ),
                        child: Text(
                          strings.memoBodySize,
                          style: TextStyle(
                            color: const Color(0xFFECECEC),
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            '가',
                            style: TextStyle(
                              color: Color(0xFF9A9AA2),
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: fontSize,
                              min: SettingsService.minBodyFontSize,
                              max: SettingsService.maxBodyFontSize,
                              divisions:
                                  (SettingsService.maxBodyFontSize -
                                          SettingsService.minBodyFontSize)
                                      .round(),
                              activeColor: const Color(0xFF7C5CFF),
                              label: fontSizeLabel,
                              onChanged:
                                  SettingsService.instance.previewBodyFontSize,
                              onChangeEnd: (v) {
                                SettingsService.instance.setBodyFontSize(v);
                              },
                            ),
                          ),
                          const Text(
                            '가',
                            style: TextStyle(
                              color: Color(0xFF9A9AA2),
                              fontSize: 22,
                            ),
                          ),
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
              title: Text(
                strings.rateApp,
                style: const TextStyle(color: Colors.white),
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
              leading: const Icon(Icons.feedback_outlined, color: Colors.white),
              title: Text(
                strings.sendFeedback,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _sendFeedback,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.removeAds,
              builder: (context, removed, _) {
                if (removed) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF7C5CFF),
                    ),
                    title: Text(
                      strings.removeAdsDone,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      strings.thanksForUsing,
                      style: const TextStyle(color: Color(0xFF9A9AA2)),
                    ),
                  );
                }
                final available = RemoveAdsPurchase.instance.available;
                final price = RemoveAdsPurchase.instance.price;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: const Icon(
                        Icons.block_outlined,
                        color: Color(0xFF7C5CFF),
                      ),
                      title: Text(
                        strings.removeAds,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        available
                            ? (price ?? strings.removeAdsOneTime)
                            : strings.removeAdsPrepared,
                        style: const TextStyle(color: Color(0xFF9A9AA2)),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF7C5CFF),
                      ),
                      onTap: _buyRemoveAds,
                    ),
                    const Divider(height: 0.5, thickness: 0.5),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: const Icon(
                        Icons.restore,
                        color: Color(0xFF9A9AA2),
                      ),
                      title: Text(
                        strings.restorePurchases,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9A9AA2),
                      ),
                      onTap: _restorePurchases,
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.backup_outlined, color: Colors.white),
              title: Text(
                strings.backupRestore,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _openBackupRestore,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: Text(
                strings.trash,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _openTrash,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.translate, color: Colors.white),
              title: Text(
                strings.language,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                SettingsService.instance.languageCode.value == 'en'
                    ? strings.english
                    : strings.korean,
                style: const TextStyle(color: Color(0xFF9A9AA2)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _openLanguageMenu,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.help_outline, color: Colors.white),
              title: Text(
                strings.helpFaq,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: _openHelp,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.description_outlined,
                color: Colors.white70,
              ),
              title: Text(
                strings.terms,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () =>
                  _openPolicy(strings.terms, 'docs/legal/terms-of-service.md'),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: Colors.white70,
              ),
              title: Text(
                strings.privacy,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () =>
                  _openPolicy(strings.privacy, 'docs/legal/privacy-policy.md'),
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
