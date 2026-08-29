import 'package:flutter/widgets.dart';

import '../features/memos/services/mini_lm_model_manifest.dart';
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
  // ★구독(premium_monthly) 판매 문구 전량 삭제 — T-260805-076.
  //   지운 것 = premiumTitle/Subtitle/Active/Expires/PaywallTitle/PaywallBody/
  //   Subscribe/Price/StorePriceFallback/Prepared/Restore. 삭제 시점 호출처 0곳이었다.
  //   ★남겨 두지 않은 이유 = 이 getter 들이 「월 ₩1,900」을 문자열로 들고 있었다.
  //   상품이 없는데 가격 문구가 코드에 남아 있으면, 화면에 한 줄 붙이는 것만으로
  //   팔지 않는 물건이 되살아난다. 되살리려면 상품 등록이 먼저다.

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
  // ★premiumCouponNote / premiumTermsNote 삭제 — T-260805-076. 둘 다 결제화면 전용이었고
  //   그 화면이 사라져 호출처가 0곳이었다. TermsNote 는 「매월 자동 갱신」을 말하는데
  //   자동갱신 상품 자체가 없어졌으므로 남기면 거짓 고지가 된다.
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

  // ---- T-260719-019 영어 로케일 한글 잔존 전수 이관 ----
  // 공용 액션
  String get cancel => isEnglish ? 'Cancel' : '취소';
  String get delete => isEnglish ? 'Delete' : '삭제';
  String get save => isEnglish ? 'Save' : '저장';
  String get back => isEnglish ? 'Back' : '뒤로';
  String get share => isEnglish ? 'Share' : '공유';
  String get edit => isEnglish ? 'Edit' : '편집';
  String get install => isEnglish ? 'Install' : '설치';
  String get search => isEnglish ? 'Search' : '검색';
  String get undo => isEnglish ? 'Undo' : '되돌리기';
  String get undoSpaced => isEnglish ? 'Undo' : '실행 취소';

  // 백업 & 복원 화면
  String get noMemosToExport => isEnglish ? 'No memos to export' : '내보낼 메모가 없습니다';
  String get driveBackupStarting =>
      isEnglish ? 'Starting Drive backup' : 'Drive 백업을 시작합니다';
  String get driveSaved => isEnglish ? 'Saved to Drive' : 'Drive 에 저장됐어요';
  String get openMemoyoFolder => isEnglish ? 'Open Memoyo folder' : 'Memoyo 폴더 열기';
  String get checkInternet =>
      isEnglish ? 'Check your internet connection' : '인터넷 연결을 확인해주세요';
  String get drivePermissionNeeded =>
      isEnglish ? 'Drive permission is required' : 'Drive 권한이 필요해요';
  String get driveQuotaExceeded =>
      isEnglish ? 'Not enough Drive storage' : 'Drive 용량이 부족해요';
  String driveBackupFailed(Object message) =>
      isEnglish ? 'Drive backup failed: $message' : 'Drive 백업 실패: $message';
  String get driveImportLabel => isEnglish ? 'Drive import' : 'Drive 가져오기';
  String get driveBackupLabel => isEnglish ? 'Drive backup' : 'Drive 백업';
  String actionFailed(String label, Object message) =>
      isEnglish ? '$label failed: $message' : '$label 실패: $message';
  String actionDone(String label) => isEnglish ? '$label done' : '$label 완료';
  String get noBackupFileOnDrive =>
      isEnglish ? 'No backup file on Drive' : 'Drive 에 백업 파일이 없어요';
  String get noMemosToImport => isEnglish ? 'No memos to import' : '가져올 메모가 없습니다';
  String importedMemos(int incoming, int total) => isEnglish
      ? 'Imported $incoming memos (total $total)'
      : '메모 $incoming개 가져왔습니다 (전체 $total개)';
  String get invalidBackupFile =>
      isEnglish ? 'Not a valid Memoyo backup file' : '올바른 메모요 백업 파일이 아닙니다';
  String restoredPrevious(int count) => isEnglish
      ? 'Restored previous $count memos'
      : '이전 메모 $count개로 되돌렸습니다';
  String get driveBackupChoose => isEnglish ? 'Choose Drive backup' : 'Drive 백업 선택';
  String get neverBackedUp => isEnglish ? 'No backup yet' : '아직 백업한 적 없어요';
  String lastBackupAt(String stamp) =>
      isEnglish ? 'Last backup: $stamp' : '마지막 백업: $stamp';
  String get backupIntro => isEnglish
      ? 'Back up memos safely to Google Drive\nand restore them when needed.'
      : '메모를 Google Drive 에 안전하게 백업하고,\n필요할 때 다시 복원할 수 있어요.';
  String backupTarget(int count) => isEnglish
      ? 'Backup target: $count active memos (Trash excluded)'
      : '백업 대상: 활성 메모 $count개 (휴지통 제외)';
  String get backingUp => isEnglish ? 'Backing up…' : '백업 중…';
  String get backupNow => isEnglish ? 'Back up now' : '지금 백업';
  String get restoring => isEnglish ? 'Restoring…' : '복원 중…';
  String get restore => isEnglish ? 'Restore' : '복원';

  // 메모 편집 화면
  String get redo => isEnglish ? 'Redo' : '다시실행';
  String get undoAction => isEnglish ? 'Undo' : '실행취소';
  String get whichAction => isEnglish ? 'Which action would you like?' : '어떤 작업을 할까요?';
  String get enterContent => isEnglish ? 'Please enter some content.' : '내용을 입력해주세요.';
  String get nothingToShare => isEnglish ? 'Nothing to share.' : '공유할 내용이 없습니다.';
  String shareFailed(Object error) =>
      isEnglish ? 'Share failed: $error' : '공유 실패: $error';
  String get discardConfirmTitle => isEnglish ? 'Discard changes?' : '취소하시겠습니까?';
  String get discardConfirmBody =>
      isEnglish ? 'Your edits will not be saved.' : '수정한 내용이 저장되지 않습니다.';
  String get keepEditing => isEnglish ? 'Keep editing' : '계속수정';
  String get editMemoTitle => isEnglish ? 'Edit memo' : '메모수정';
  String get newMemoTitle => isEnglish ? 'New memo' : '새메모';
  String get contentHint => isEnglish ? 'Type your memo...' : '내용을 입력하세요...';

  // 기기 내 뜻 검색 모델 (MiniLM) 행·다이얼로그
  String get miniLmTitle =>
      isEnglish ? 'On-device semantic search model' : '기기 내 뜻 검색 모델';
  String get miniLmChecking =>
      isEnglish ? 'Checking install status' : '설치 상태 확인 중';
  String get miniLmUnsupported => isEnglish
      ? 'This device uses Gemini search'
      : '이 기기에서는 Gemini 검색을 사용합니다';
  // T-260811-015: 용량 표기 기준을 여기 한 곳에 고정한다 — MB = 10^6(십진), 올림.
  //   근거 ①다운로드 용량은 스토어·통신사 관행이 십진이다 ②올림이라 실제보다 작게
  //   안내하는 일이 없다. 종전 문구의 '124MB' 는 하드코딩이었고 매니페스트 합계
  //   123,481,449B 와 도출 관계가 끊겨 있었다 — 상수가 바뀌면 문구가 조용히 거짓말한다.
  //   ⇒ 설치 전·후·설치 안내가 모두 이 하나를 쓴다.
  static String get _downloadSizeLabel =>
      '${(MiniLmModelManifest.totalDownloadBytes / 1000000).ceil()}MB';

  /// 개별 파일용 — 합계와 달리 소수 1자리로 보여 준다(다이얼로그 전용).
  static String _fileSizeLabel(int bytes) =>
      '${(bytes / 1000000).toStringAsFixed(1)}MB';

  String get miniLmAbsent => isEnglish
      ? 'About $_downloadSizeLabel · Wi-Fi recommended · ${MiniLmModelManifest.license}'
      : '약 $_downloadSizeLabel · Wi-Fi 권장 · ${MiniLmModelManifest.license}';
  String miniLmDownloading(int percent) =>
      isEnglish ? 'Downloading $percent%' : '다운로드 중 $percent%';
  // T-260811-015: 설치 후에 모델 정체가 화면에서 사라지던 문제(아니키 지적 2026-08-11).
  //   설치 전에는 용량·라이선스가 보이는데 설치되면 「설치됨」 한 줄만 남아,
  //   무엇이 깔렸는지 확인할 방법이 앱 안에 없었다.
  //   ★이 라벨은 표시 전용이다. manifest 의 engineId 주석이 못박은 대로
  //    짧은 표시 라벨을 semanticEmbeddingModel 에 저장해서는 안 된다 — 여기서
  //    만든 문자열은 어떤 저장 경로로도 흘러가지 않는다(표시층 한정).
  String get miniLmReady => isEnglish
      ? 'MiniLM multilingual model · $_downloadSizeLabel · '
            '${MiniLmModelManifest.license} · offline search ready'
      : 'MiniLM 다국어 모델 · $_downloadSizeLabel · '
            '${MiniLmModelManifest.license} · 오프라인 검색 가능';
  String get miniLmInsufficientSpace => isEnglish
      ? 'Not enough storage · try again'
      : '저장 공간이 부족합니다 · 다시 시도';
  String get miniLmManifestInvalid =>
      isEnglish ? 'Model verification failed · try again' : '모델 검증 실패 · 다시 시도';
  String get miniLmInstallFailed => isEnglish ? 'Install failed · try again' : '설치 실패 · 다시 시도';
  String get miniLmDeleteTooltip => isEnglish ? 'Delete model' : '모델 삭제';
  String get miniLmInstallTitle =>
      isEnglish ? 'Install semantic search model' : '뜻 검색 모델 설치';
  String get miniLmInstallBody => isEnglish
      ? 'Downloads the MiniLM model and tokenizer (about $_downloadSizeLabel). '
          'Wi-Fi is recommended, and you can delete it anytime in Settings. '
          'Files must pass the SHA-256 verification pinned in the app to be installed.'
      : 'MiniLM 모델과 토크나이저 약 $_downloadSizeLabel를 다운로드합니다. '
          'Wi-Fi 사용을 권장하며 설정에서 언제든 삭제할 수 있습니다. '
          '파일은 앱에 고정된 SHA-256 검증을 통과해야 설치됩니다.';
  String get miniLmDeleteTitle =>
      isEnglish ? 'Delete semantic search model' : '뜻 검색 모델 삭제';
  String get miniLmDeleteBody => isEnglish
      ? 'Deletes the stored model file. Your memos are not deleted.'
      : '저장된 모델 파일을 삭제합니다. 기존 메모는 삭제되지 않습니다.';

  // T-260811-015: 설치된 모델 상세. 서브타이틀 한 줄에 해시·revision 까지 넣으면
  //   읽을 수 없으므로 탭했을 때만 편다. 값은 전부 매니페스트 상수에서 온다.
  String get miniLmDetailsTitle =>
      isEnglish ? 'Installed model' : '설치된 모델 정보';
  String get miniLmDetailsClose => isEnglish ? 'Close' : '닫기';

  /// sha256·revision 은 앞 12자·8자만 — 대조에는 충분하고 한 줄을 넘기지 않는다.
  String get miniLmDetailsBody {
    const m = MiniLmModelManifest.model;
    const t = MiniLmModelManifest.tokenizer;
    final revision = MiniLmModelManifest.revision.substring(0, 8);
    final modelHash = m.sha256.substring(0, 12);
    final tokenizerHash = t.sha256.substring(0, 12);
    if (isEnglish) {
      return 'Repository\n${MiniLmModelManifest.repository}\n\n'
          'Revision\n$revision\n\n'
          'License\n${MiniLmModelManifest.license}\n\n'
          'Vectors\n${MiniLmModelManifest.dimensions} dimensions · '
          'up to ${MiniLmModelManifest.maxSequenceLength} tokens\n\n'
          'Files\n${m.name} · ${_fileSizeLabel(m.size)} · sha256 $modelHash\n'
          '${t.name} · ${_fileSizeLabel(t.size)} · sha256 $tokenizerHash';
    }
    return '저장소\n${MiniLmModelManifest.repository}\n\n'
        '리비전\n$revision\n\n'
        '라이선스\n${MiniLmModelManifest.license}\n\n'
        '벡터\n${MiniLmModelManifest.dimensions}차원 · '
        '최대 ${MiniLmModelManifest.maxSequenceLength}토큰\n\n'
        '파일\n${m.name} · ${_fileSizeLabel(m.size)} · sha256 $modelHash\n'
        '${t.name} · ${_fileSizeLabel(t.size)} · sha256 $tokenizerHash';
  }

  // 메모 목록 화면
  String get deleteMemoTitle => isEnglish ? 'Delete memo' : '메모삭제';
  String deleteSelectedConfirm(int count) => isEnglish
      ? 'Delete the $count selected memos?'
      : '선택한 $count개 메모를 삭제하시겠습니까?';
  String get memoDeleted => isEnglish ? 'Memo deleted' : '메모를 삭제했습니다';
  String memosDeleted(int count) =>
      isEnglish ? 'Deleted $count memos' : '메모 $count개를 삭제했습니다';
  String deleteMemoConfirm(String firstLine) => isEnglish
      ? 'Delete memo "$firstLine"?'
      : '"$firstLine" 메모를 삭제하시겠습니까?';
  String get deselectAll => isEnglish ? 'Deselect all' : '선택해제';
  String get selectAll => isEnglish ? 'Select all' : '전체선택';
  String deleteWithCount(int count) =>
      isEnglish ? 'Delete ($count)' : '삭제 ($count)';
  String get emptyMemoHint => isEnglish
      ? 'No memos yet.\nTap the New tab below to write your first memo.'
      : '아직 메모가 없어요.\n아래 새메모 탭을 눌러 첫 메모를 남겨보세요.';

  // 휴지통 화면
  String get memoRestored => isEnglish ? 'Memo restored' : '메모를 복구했습니다';
  String get purgeSoon => isEnglish ? 'Permanently deleted soon' : '곧 영구삭제';
  String purgeAfterDays(int days) => isEnglish
      ? 'Permanently deleted in $days days'
      : '$days일 후 영구삭제';
  String get restoreAction => isEnglish ? 'Restore' : '복구';
  String get purgeNow => isEnglish ? 'Delete permanently now' : '즉시 영구삭제';
  String get emptyTrashTitle => isEnglish ? 'Empty Trash' : '휴지통 비우기';
  String emptyTrashConfirm(int count) => isEnglish
      ? 'Permanently delete $count memos in Trash?\nThis cannot be undone.'
      : '휴지통의 $count개 메모를 영구 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
  String get emptyTrashAction => isEnglish ? 'Empty' : '비우기';
  String get trashEmptyHint => isEnglish
      ? 'Trash is empty.\nDeleted memos are kept for 30 days.'
      : '휴지통이 비어있습니다.\n삭제한 메모는 30일간 보관됩니다.';

  // 검색 화면
  String get searchHint => isEnglish ? 'Search memos' : '메모 검색';
  String get clearTooltip => isEnglish ? 'Clear' : '지우기';
  String get keywordSearch => isEnglish ? 'Keyword search' : '일반 검색';
  String get semanticSearch => isEnglish ? 'Semantic search' : '뜻으로 찾기';
  String get searchPrompt =>
      isEnglish ? 'Search your memo content.' : '메모 내용을 검색해 보세요.';
  String noSearchResults(String query) => isEnglish
      ? 'No results for "$query".\nTry a different search term.'
      : '"$query" 검색 결과가 없습니다.\n다른 검색어로 시도해 보세요.';
  String get semanticFallbackNotice => isEnglish
      ? 'Semantic search is unavailable — showing keyword results.'
      : '뜻 검색을 사용할 수 없어 일반 검색으로 표시 중입니다.';
  String memoResults(int count) =>
      isEnglish ? 'Memo results ($count)' : '메모 결과 ($count건)';

  // 설정 화면 (테마·폰트 미리보기)
  String get fontSample => isEnglish ? 'A' : '가';
  String get theme => isEnglish ? 'Theme' : '테마';
  String get themeSystem => isEnglish ? 'System' : '시스템';
  String get themeLight => isEnglish ? 'Light' : '라이트';
  String get themeDark => isEnglish ? 'Dark' : '다크';

  // 프리미엄 paywall 기능 라벨
  //   ※ AI 요약 라벨은 T-260804-078 에서 제거했다 — 기능이 T-260804-062 로 사라졌는데
  //     결제화면만 계속 팔고 있었다. 되살리려면 기능이 먼저다.
  // ★premiumFeatureSemanticSearch / premiumFeatureAdFree 삭제 — T-260805-076.
  //   구독 혜택 목록이었고 결제화면에서만 쓰였다. 광고 숨김은 이제 구독 기간이 아니라
  //   광고제거 단품(remove_ads)이 주는 것이라, 문구를 옮기지 않고 지운다.

  // 기타
  String get madeBy => isEnglish ? 'Minus Beta Studio' : '마이너스베타스튜디오';
  String versionLine(String version) =>
      isEnglish ? 'v$version · Minus Beta Studio' : 'v$version · 마이너스베타스튜디오';
  String get docLoadFailed =>
      isEnglish ? 'Could not load the document' : '문서를 불러올 수 없습니다';
  String get untitledMemo => isEnglish ? 'New memo' : '새 메모';

  // 메모 이미지 첨부 (T-260829-022)
  String get addPhoto => isEnglish ? 'Add photo' : '사진 추가';
  String get fromGallery => isEnglish ? 'Photo library' : '사진첩';
  String get fromCamera => isEnglish ? 'Camera' : '카메라';
  String get pasteImage => isEnglish ? 'Paste' : '붙여넣기';
  String get noImageInClipboard => isEnglish
      ? 'No image in clipboard, or paste was not allowed'
      : '클립보드에 사진이 없거나 붙여넣기가 허용되지 않았어요';
  String get cameraPermissionDenied => isEnglish
      ? 'Allow camera access in Settings to take a photo'
      : '사진을 찍으려면 설정에서 카메라 권한을 허용해 주세요';
  String get photoLimitReached =>
      isEnglish ? 'Up to 10 photos per memo' : '사진은 메모당 최대 10장까지예요';
  String get photoAttachFailed =>
      isEnglish ? "Couldn't add the photo" : '사진을 추가하지 못했어요';
  String get deletePhotoConfirmTitle => isEnglish ? 'Delete photo' : '사진 삭제';
  String get deletePhotoConfirmBody =>
      isEnglish ? 'Delete this photo?' : '이 사진을 지울까요?';
  String get photosNotInBackup => isEnglish
      ? 'Photos are not included in backups'
      : '사진은 백업에 포함되지 않습니다';
  String get photoMissing => isEnglish ? 'Photo missing' : '사진 없음';
  String get attachedPhoto => isEnglish ? 'Attached photo' : '첨부 사진';
  String get photoViewerClose => isEnglish ? 'Close' : '닫기';
}
