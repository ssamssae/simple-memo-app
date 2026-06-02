import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

enum AppReviewResult { requested, openedStoreListing, unavailable }

class AppReviewService {
  AppReviewService({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  static const appStoreId = '6762068073';

  final InAppReview _inAppReview;

  Future<AppReviewResult> requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return AppReviewResult.requested;
      }
    } catch (error) {
      debugPrint('[AppReviewService.requestReview] $error');
    }

    try {
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
      return AppReviewResult.openedStoreListing;
    } catch (error) {
      debugPrint('[AppReviewService.openStoreListing] $error');
      return AppReviewResult.unavailable;
    }
  }
}
