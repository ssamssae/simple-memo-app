import 'package:flutter/material.dart';

import '../services/app_review_service.dart';
import '../widgets/version_footer.dart';

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
          ],
        ),
      ),
    );
  }
}
