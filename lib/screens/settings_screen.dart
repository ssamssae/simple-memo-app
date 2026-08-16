import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../features/memos/semantic_search_availability.dart';
import '../features/memos/services/embedding_engine.dart';
import '../features/memos/services/mini_lm_model_controller.dart';
import '../features/memos/services/mini_lm_model_installer.dart';
import '../features/memos/services/mini_lm_runtime.dart';
import '../features/memos/widgets/mini_lm_model_settings_tile.dart';
import '../services/ads_service.dart';
import '../services/app_review_service.dart';
import '../services/remove_ads_purchase.dart';
import '../services/settings_service.dart';
import '../widgets/version_footer.dart';
import '../utils/app_palette.dart';
import 'backup_restore_screen.dart';
import 'help_faq_screen.dart';
import 'policy_screen.dart';
import 'trash_screen.dart';

/// ★구독(premium_monthly) ★완전 제거 — T-260805-076 (선행 T-260804-090 은 진입만 절단).
///
/// 아니키 결정 2026-08-04: 구독 상품을 접고 광고제거 단품(remove_ads)만 판다.
/// 2026-08-05 지시로 잔존 코드까지 걷었다 — 이 앱이 파는 상품은 이제 `remove_ads` 하나뿐이다.
///
/// ■유예(grandfather)를 접은 근거 = ★구독 결제자 0명
///   T-260804-090 시점에는 「돈 낸 사람의 혜택을 뺏지 않는다」로 읽는 쪽을 남겼는데,
///   그때는 실인원을 몰랐다. T-260805-001 이 3면 독립 실측으로 ★0명을 확정했다
///   (서버 엔티틀먼트 D1 `memoyo_entitlements` 0 · `memoyo_coupon_grants` 0, 양성 대조군 `orders` 11).
///   보호할 대상이 0명이면 유예는 보호가 아니라 죽은 코드다. ⇒ 걷었다.
///
/// ■그런데 왜 `PremiumService` 는 남아 있나
///   그건 파는 쪽이 아니라 ★읽는 쪽이다. 광고제거 구매자의 서버 쿠폰 엔티틀먼트
///   (`claimRemoveAdsCoupon`, source=removeAdsCoupon)를 받아 `ad_banner` 가 배너를 끄는 축이다.
///   이름에 premium 이 들어갔다고 구독 코드로 오독하지 마라 — 지우면 광고제거가 깨진다.
///
/// ■이 화면에서 함께 사라진 것 = 「프리미엄」 엔티틀먼트 카드
///   entitlement.active 로만 렌더하던 칸인데, ★remove_ads 쿠폰도 그 플래그를 켠다.
///   구독이 없어진 뒤에도 남겨 두면 ₩3,300 광고제거를 산 사람에게 「프리미엄」이라고
///   잘못 이름 붙이게 된다. 없는 상품의 이름을 화면에 남기지 않는다.
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
  //   _openPaywall 은 이 화면의 유일한 판매 진입이었다. 구독 상품 완전 제거(T-260805-076, #123)로
  //   PaywallScreen 파일 자체도 함께 삭제됐다 — 이 주석 정정은 T-260815-060.

  Future<void> _openLanguageMenu() async {
    final strings = AppStrings.of(context);
    final palette = AppPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.elevatedSurface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(strings.language),
              textColor: palette.textPrimary,
            ),
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
      textColor: AppPalette.of(sheetContext).textPrimary,
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

  // ★복원 대상은 광고제거(remove_ads) 단품 하나다 — T-260805-076.
  //   종전에는 구독 래퍼(PremiumPurchase)를 통해 복원을 걸었는데, 그 클래스가
  //   사라졌다. 스토어 API 호출 자체는 상품 구분 없는 restorePurchases() 라서
  //   동작은 동일하고, ★파는 상품이 하나뿐인 현실과 코드가 같은 말을 하게 됐다.
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
            // ★「프리미엄」 엔티틀먼트 카드 제거 — T-260805-076. 사유는 이 화면 상단 주석.
            // ★T-260805-145 — 말로찾기가 잠긴 동안에는 이 타일이 124MB 설치를 권하지 않는다.
            //   판정은 miniLmTileVisible 하나뿐이다(리터럴 복제 금지 — availability 파일 주석).
            //   AnimatedBuilder 로 감싸는 이유 = 설치가 끝나 ready 로 바뀌는 순간 타일이
            //   나타나야 하고, 삭제로 absent 가 되면 다시 사라져야 하기 때문이다.
            if (_miniLmModelManager case final manager?)
              AnimatedBuilder(
                animation: manager,
                builder: (context, _) {
                  final visible = miniLmTileVisible(
                    installed: manager.state == MiniLmModelState.ready,
                  );
                  if (!visible) return const SizedBox.shrink();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MiniLmModelSettingsTile(manager: manager),
                      const Divider(height: 0.5, thickness: 0.5),
                    ],
                  );
                },
              ),
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
