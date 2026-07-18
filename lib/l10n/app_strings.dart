import 'package:flutter/widgets.dart';

import '../services/settings_service.dart';

class AppStrings {
  const AppStrings._(this.languageCode);

  final String languageCode;

  static const supportedLanguageCodes = ['ko', 'en'];

  static AppStrings of(BuildContext context) =>
      fromCode(SettingsService.instance.languageCode.value);

  static AppStrings fromCode(String code) =>
      code == 'en' ? const AppStrings._('en') : const AppStrings._('ko');

  bool get isEnglish => languageCode == 'en';

  String get appName => isEnglish ? 'Memoyo' : '메모요';
  String get settings => isEnglish ? 'Settings' : '설정';
  String get memoTab => isEnglish ? 'Memo' : '메모';
  String get newMemoTab => isEnglish ? 'New' : '새메모';
  String get fontSize => isEnglish ? 'Text size' : '글자 크기';
  String get memoBodySize => isEnglish ? 'Memo body size' : '메모 본문 크기';
  String get language => isEnglish ? 'Language' : '언어';
  String get korean => isEnglish ? 'Korean' : '한국어';
  String get english => 'English';
  String get helpFaq => isEnglish ? 'Help & FAQ' : '도움말 / FAQ';
  String get rateApp => isEnglish ? 'Rate this app' : '앱 평가하기';
  String get sendFeedback => isEnglish ? 'Send feedback' : '피드백 보내기';
  String get removeAdsDone => isEnglish ? 'Ads removed' : '광고 제거됨';
  String get thanksForUsing =>
      isEnglish ? 'Thanks for using Memoyo' : '이용해 주셔서 감사합니다';
  String get removeAds => isEnglish ? 'Remove ads' : '광고 제거';
  String get removeAdsPrepared => isEnglish ? 'Preparing product' : '상품 준비중';
  String get removeAdsOneTime =>
      isEnglish ? 'Remove banner ads with one purchase' : '한 번 결제로 배너 광고 제거';
  String get premiumTitle => isEnglish ? 'Memoyo Premium' : '메모요 프리미엄';
  String get premiumSubtitle => isEnglish
      ? 'AI summary and semantic search · ₩1,900/month'
      : 'AI 요약과 말로 검색 · 월 ₩1,900';
  String get premiumActive => isEnglish ? 'Premium active' : '프리미엄 사용 중';
  String premiumExpires(DateTime expiresAt) => isEnglish
      ? 'Available until ${expiresAt.toLocal().year}-${expiresAt.toLocal().month.toString().padLeft(2, '0')}-${expiresAt.toLocal().day.toString().padLeft(2, '0')}'
      : '${expiresAt.toLocal().year}.${expiresAt.toLocal().month.toString().padLeft(2, '0')}.${expiresAt.toLocal().day.toString().padLeft(2, '0')}까지 사용 가능';
  String get premiumPaywallTitle =>
      isEnglish ? 'Upgrade to Premium' : '프리미엄으로 업그레이드';
  String get premiumPaywallBody => isEnglish
      ? 'Use AI summaries and semantic search, and focus without banner ads while Premium is active.'
      : 'AI 요약과 말로 검색을 이용하고, 프리미엄 기간에는 배너 광고 없이 메모에 집중하세요.';
  String get premiumSubscribe => isEnglish ? 'Subscribe monthly' : '월 구독 시작';
  String premiumPrice(String price) =>
      isEnglish ? '$price / month' : '월 $price';
  String get premiumStorePriceFallback =>
      isEnglish ? '₩1,900 / month' : '월 ₩1,900';
  String get premiumPrepared =>
      isEnglish ? 'Subscription product is being prepared' : '구독 상품을 준비 중이에요';
  String get premiumRestore => isEnglish ? 'Restore Premium' : '프리미엄 복원';

  // T-260719-018: 온디바이스 모델 설치 진행/실패 피드백 (신규 문구 — 기존 문구 이관은 T-260719-019)
  String get minilmPreparingDownload =>
      isEnglish ? 'Preparing download…' : '다운로드 준비 중…';
  String get minilmInstallFailedNetwork => isEnglish
      ? 'Install failed: network interrupted · Tap to retry'
      : '설치 실패: 네트워크 중단 · 다시 시도';
  String get minilmInstallFailedVerify => isEnglish
      ? 'Install failed: model verification (SHA-256) failed · Tap to retry'
      : '설치 실패: 모델 검증(SHA-256) 실패 · 다시 시도';
  String get minilmInstallFailedStorage => isEnglish
      ? 'Install failed: not enough storage · Tap to retry'
      : '설치 실패: 저장 공간 부족 · 다시 시도';
  String get minilmInstallFailedGeneric =>
      isEnglish ? 'Install failed · Tap to retry' : '설치 실패 · 다시 시도';
  String get premiumCouponNote => isEnglish
      ? 'If you bought Remove ads, restore purchases to apply a one-month thank-you coupon once.'
      : '광고 제거 구매자는 구매 복원 시 1개월 감사 쿠폰이 1회 자동 적용됩니다.';
  String get premiumTermsNote => isEnglish
      ? 'Auto-renews monthly. Manage or cancel in your App Store or Google Play subscription settings.'
      : '매월 자동 갱신됩니다. 해지와 관리는 App Store 또는 Google Play 구독 설정에서 할 수 있습니다.';
  String get restorePurchases => isEnglish ? 'Restore purchases' : '구매 복원';
  String get backupRestore => isEnglish ? 'Backup & restore' : '백업 & 복원';
  String get trash => isEnglish ? 'Trash' : '휴지통';
  String get terms => isEnglish ? 'Terms of service' : '이용약관';
  String get privacy => isEnglish ? 'Privacy policy' : '개인정보처리방침';
  String get storeUnavailable =>
      isEnglish ? 'Cannot open the store' : '스토어를 열 수 없습니다';
  String get mailUnavailable =>
      isEnglish ? 'Cannot open a mail app' : '메일 앱을 열 수 없습니다';
  String get productUnavailable => isEnglish
      ? 'The product is not ready. Please try again later.'
      : '지금은 상품을 준비 중이에요. 잠시 후 다시 시도해주세요.';
  String get restoringPurchases =>
      isEnglish ? 'Restoring purchases' : '구매 내역을 복원하고 있어요.';
  String get feedbackSubject => isEnglish ? '[Memoyo feedback]' : '[메모요 피드백]';
  String feedbackBody(String version, String buildNumber) => isEnglish
      ? '\n\n\n----------\nApp: Memoyo $version+$buildNumber\n(Please write your feedback above.)'
      : '\n\n\n──────────\n앱: 메모요 $version+$buildNumber\n(위에 피드백을 적어주세요)';

  String get onboardingStartTitle =>
      isEnglish ? 'Start with Memoyo' : '메모요 시작하기';
  String get onboardingQuickTitle =>
      isEnglish ? 'Capture notes quickly' : '빠르게 메모';
  String get onboardingQuickBody => isEnglish
      ? 'Open the New tab, write, and save. Your notes stay on this device.'
      : '새메모 탭에서 바로 쓰고 저장하세요. 메모는 이 기기에 보관됩니다.';
  String get onboardingFindTitle => isEnglish ? 'Find and organize' : '찾고 정리하기';
  String get onboardingFindBody => isEnglish
      ? 'Search notes, mark favorites, and use Trash when you need to recover deleted notes.'
      : '검색으로 메모를 찾고, 즐겨찾기와 휴지통으로 안전하게 정리하세요.';
  String get onboardingBackupTitle =>
      isEnglish ? 'Backup and get help' : '백업과 도움말';
  String get onboardingBackupBody => isEnglish
      ? 'Use Settings for Drive backup, language, legal documents, app rating, and Help.'
      : '설정에서 Drive 백업, 언어, 정책 문서, 앱 평가, 도움말을 확인할 수 있어요.';
  String get next => isEnglish ? 'Next' : '다음';
  String get getStarted => isEnglish ? 'Get started' : '시작하기';
  String get skip => isEnglish ? 'Skip' : '건너뛰기';

  String get helpStorageQuestion =>
      isEnglish ? 'Where are my notes stored?' : '메모는 어디에 저장되나요?';
  String get helpStorageAnswer => isEnglish
      ? 'Notes are stored locally on your device. If you use Drive backup, the backup file is saved to your own Google Drive.'
      : '메모는 기본적으로 이 기기에 저장됩니다. Drive 백업을 사용하면 백업 파일은 본인 Google Drive에 저장됩니다.';
  String get helpBackupQuestion =>
      isEnglish ? 'How do I back up notes?' : '백업은 어떻게 하나요?';
  String get helpBackupAnswer => isEnglish
      ? 'Open Settings > Backup & restore, then choose Backup now.'
      : '설정 > 백업 & 복원에서 지금 백업을 누르면 됩니다.';
  String get helpDeleteQuestion =>
      isEnglish ? 'Can I recover deleted notes?' : '삭제한 메모를 복구할 수 있나요?';
  String get helpDeleteAnswer => isEnglish
      ? 'Deleted notes stay in Trash for 30 days before permanent deletion.'
      : '삭제한 메모는 휴지통에 30일 동안 보관된 뒤 영구 삭제됩니다.';
  String get helpFeedbackQuestion =>
      isEnglish ? 'How can I send feedback?' : '피드백은 어떻게 보내나요?';
  String get helpFeedbackAnswer => isEnglish
      ? 'Use Settings > Send feedback to open an email draft with app version details.'
      : '설정 > 피드백 보내기를 누르면 앱 버전 정보가 포함된 메일 초안이 열립니다.';
}
