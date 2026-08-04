import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../features/memos/services/embedding_engine.dart';
import '../features/memos/services/mini_lm_model_controller.dart';
import '../features/memos/services/mini_lm_model_installer.dart';
import '../features/memos/services/mini_lm_runtime.dart';
import '../features/memos/widgets/mini_lm_model_settings_tile.dart';
import '../services/ads_service.dart';
import '../services/premium_purchase.dart';
import '../services/premium_service.dart';
import '../services/app_review_service.dart';
import '../services/remove_ads_purchase.dart';
import '../services/settings_service.dart';
import '../widgets/version_footer.dart';
import 'backup_restore_screen.dart';
import 'help_faq_screen.dart';
import 'policy_screen.dart';
import 'trash_screen.dart';

/// ★구독(premium_monthly) 판매 종료 — T-260804-090 (parent T-260804-082 2페이즈).
///
/// 아니키 결정 2026-08-04: 구독 상품을 접고 광고제거 단품(remove_ads)만 판다. 이 화면에 있던
/// 결제 화면 진입(_openPaywall → PaywallScreen)과 비구독자용 판매 문구를 끊었다.
///
/// ■파는 쪽만 걷고 ★읽는 쪽은 남긴다
///   `PremiumService.isPremium` / entitlement 읽기와 `PremiumPurchase.restore` 는 그대로다.
///   기존 구독자는 아직 환불받지 못했고(T-260804-082 4페이즈, 실인원 조회조차 안 됨),
///   광고 제거가 그들에게 남은 유일한 실질 혜택이다 — 돈은 냈는데 물건이 사라지면 안 된다.
///   ⇒ 유예(grandfather)다. 제거는 환불 완주 뒤 별건으로 한다.
///
/// ■PaywallScreen 파일을 지우지 않은 이유
///   진입점을 끊으면 도달 불가가 된다. 파일을 지우면 `search_screen.dart` 의 참조까지
///   손대야 하는데 그쪽은 말로찾기 스위치(T-260804-086) 영역이라 이 티켓의 무접촉 경계다.
///   원칙 7(가역 우선)에 따라 보관하고 길만 막았다. 회귀축이 「판매 진입 0건」을 지킨다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.openReviewListing,
    this.embedded = false,
    this.miniLmModelManager,
  });

  final Future<AppReviewListingResult> Function()? openReviewListing;

  /// HomeShell 바텀바의 탭으로 임베드된 경우 true — 뒤로가기 버튼을 숨기고
  /// 버전 풋터를 바텀바 슬롯 대신 본문 하단에 렌더한다.
  final bool embedded;
  final MiniLmModelManager? miniLmModelManager;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppReviewService _appReviewService = AppReviewService();
  bool _isOpeningReviewListing = false;
  MiniLmModelManager? _miniLmModelManager;
  bool _ownsMiniLmModelManager = false;

  @override
  void initState() {
    super.initState();
    if (widget.miniLmModelManager != null) {
      _miniLmModelManager = widget.miniLmModelManager;
    } else if (SemanticEnginePolicy.configured ==
        SemanticEnginePolicy.ondevicePreferred) {
      final runtime = MethodChannelMiniLmRuntime();
      _miniLmModelManager = MiniLmModelController(
        installer: MiniLmModelInstaller(
          freeSpaceProvider: runtime.availableBytes,
        ),
        runtime: runtime,
      );
      _ownsMiniLmModelManager = true;
    }
    final manager = _miniLmModelManager;
    if (manager != null) unawaited(manager.refresh());
  }

  @override
  void dispose() {
    if (_ownsMiniLmModelManager) _miniLmModelManager?.dispose();
    super.dispose();
  }

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

  // ★구독 판매 종료 (T-260804-090, parent T-260804-082 2페이즈)로 결제 화면 진입점을 끊었다.
  //   _openPaywall 은 이 화면의 유일한 판매 진입이었고, 지금은 부르는 곳이 없어 함께 제거한다.
  //   PaywallScreen 파일 자체는 지우지 않았다 — 사유는 이 화면 상단 주석 참조.

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
    await PremiumPurchase.instance.restore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).restoringPurchases)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.onSurface;
    final secondaryColor = colorScheme.onSurfaceVariant;
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
                          Icon(Icons.format_size, color: primaryColor),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Text(
                              strings.fontSize,
                              style: TextStyle(color: primaryColor),
                            ),
                          ),
                          Text(
                            fontSizeLabel,
                            style: TextStyle(color: secondaryColor),
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
                            color: primaryColor,
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            AppStrings.of(context).fontSample,
                            style: TextStyle(
                              color: secondaryColor,
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
                          Text(
                            AppStrings.of(context).fontSample,
                            style: TextStyle(
                              color: secondaryColor,
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
            ValueListenableBuilder<ThemeMode>(
              valueListenable: SettingsService.instance.themeMode,
              builder: (context, themeMode, _) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.contrast, color: primaryColor),
                      const SizedBox(width: 32),
                      Text(AppStrings.of(context).theme, style: TextStyle(color: primaryColor)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          selected: {themeMode},
                          style: const ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              label: Text(AppStrings.of(context).themeSystem),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              label: Text(AppStrings.of(context).themeLight),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              label: Text(AppStrings.of(context).themeDark),
                            ),
                          ],
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            SettingsService.instance.setThemeMode(
                              selection.first,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.star_rate_outlined, color: primaryColor),
              title: Text(
                strings.rateApp,
                style: TextStyle(color: primaryColor),
              ),
              trailing: _isOpeningReviewListing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chevron_right, color: primaryColor),
              onTap: _isOpeningReviewListing ? null : _openReviewListing,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.feedback_outlined, color: primaryColor),
              title: Text(
                strings.sendFeedback,
                style: TextStyle(color: primaryColor),
              ),
              trailing: Icon(Icons.chevron_right, color: primaryColor),
              onTap: _sendFeedback,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ValueListenableBuilder(
              valueListenable: PremiumService.instance.entitlement,
              builder: (context, entitlement, _) {
                // ★구독 판매 종료 (T-260804-090, parent T-260804-082 2페이즈).
                //   비구독자에게는 이 칸 자체를 안 보인다 — 그래야 파는 문구
                //   (strings.premiumSubtitle)와 결제 진입이 ★동시에 사라진다. 문구만 바꾸고
                //   칸을 남기면 「눌러도 아무 일 없는 카드」가 되고, 그건 죽은 버튼이다.
                //   구독중인 사람에게는 만료일만 남긴다 — 없애면 자기 구독이 언제까지인지
                //   볼 곳이 사라진다. onTap·chevron 을 뗐으므로 여기서 결제로 갈 길은 없다.
                if (!entitlement.active) return const SizedBox.shrink();
                final expiresAt = entitlement.expiresAt;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: const Icon(
                        Icons.verified_outlined,
                        color: Color(0xFF7C5CFF),
                      ),
                      title: Text(
                        strings.premiumTitle,
                        style: TextStyle(color: primaryColor),
                      ),
                      subtitle: expiresAt == null
                          ? null
                          : Text(
                              strings.premiumExpires(expiresAt),
                              style: TextStyle(color: secondaryColor),
                            ),
                    ),
                    const Divider(height: 0.5, thickness: 0.5),
                  ],
                );
              },
            ),
            if (_miniLmModelManager case final manager?) ...[
              MiniLmModelSettingsTile(manager: manager),
              const Divider(height: 0.5, thickness: 0.5),
            ],
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
                      style: TextStyle(color: primaryColor),
                    ),
                    subtitle: Text(
                      strings.thanksForUsing,
                      style: TextStyle(color: secondaryColor),
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
                        style: TextStyle(color: primaryColor),
                      ),
                      subtitle: Text(
                        available
                            ? (price ?? strings.removeAdsOneTime)
                            : strings.removeAdsPrepared,
                        style: TextStyle(color: secondaryColor),
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
                      leading: Icon(Icons.restore, color: secondaryColor),
                      title: Text(
                        strings.restorePurchases,
                        style: TextStyle(color: primaryColor),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: secondaryColor,
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
              leading: Icon(Icons.backup_outlined, color: primaryColor),
              title: Text(
                strings.backupRestore,
                style: TextStyle(color: primaryColor),
              ),
              trailing: Icon(Icons.chevron_right, color: primaryColor),
              onTap: _openBackupRestore,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.delete_outline, color: primaryColor),
              title: Text(strings.trash, style: TextStyle(color: primaryColor)),
              trailing: Icon(Icons.chevron_right, color: primaryColor),
              onTap: _openTrash,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.translate, color: primaryColor),
              title: Text(
                strings.language,
                style: TextStyle(color: primaryColor),
              ),
              subtitle: Text(
                SettingsService.instance.languageCode.value == 'en'
                    ? strings.english
                    : strings.korean,
                style: TextStyle(color: secondaryColor),
              ),
              trailing: Icon(Icons.chevron_right, color: primaryColor),
              onTap: _openLanguageMenu,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.help_outline, color: primaryColor),
              title: Text(
                strings.helpFaq,
                style: TextStyle(color: primaryColor),
              ),
              trailing: Icon(Icons.chevron_right, color: primaryColor),
              onTap: _openHelp,
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.description_outlined, color: secondaryColor),
              title: Text(strings.terms, style: TextStyle(color: primaryColor)),
              trailing: Icon(Icons.chevron_right, color: secondaryColor),
              onTap: () =>
                  _openPolicy(strings.terms, 'docs/legal/terms-of-service.md'),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(Icons.privacy_tip_outlined, color: secondaryColor),
              title: Text(
                strings.privacy,
                style: TextStyle(color: primaryColor),
              ),
              trailing: Icon(Icons.chevron_right, color: secondaryColor),
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
