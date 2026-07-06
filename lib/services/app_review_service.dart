import 'package:in_app_review/in_app_review.dart';

enum AppReviewListingResult { opened, unavailable }

enum AppReviewPromptResult { requested, unavailable }

class AppReviewService {
  AppReviewService({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  static const appStoreId = '6762068073';

  final InAppReview _inAppReview;

  Future<AppReviewListingResult> openReviewListing() async {
    try {
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
      return AppReviewListingResult.opened;
    } catch (_) {
      return AppReviewListingResult.unavailable;
    }
  }

  Future<AppReviewPromptResult> requestInAppReview() async {
    try {
      if (!await _inAppReview.isAvailable()) {
        return AppReviewPromptResult.unavailable;
      }
      await _inAppReview.requestReview();
      return AppReviewPromptResult.requested;
    } catch (_) {
      return AppReviewPromptResult.unavailable;
    }
  }
}
