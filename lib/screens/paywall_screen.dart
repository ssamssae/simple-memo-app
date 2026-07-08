import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/ads_service.dart';
import '../services/premium_purchase.dart';
import '../services/premium_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;

  Future<void> _subscribe() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await PremiumPurchase.instance.buy();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).productUnavailable)),
      );
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    await PremiumPurchase.instance.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).restoringPurchases)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final productPrice = PremiumPurchase.instance.price;
    final priceText = productPrice == null
        ? strings.premiumStorePriceFallback
        : strings.premiumPrice(productPrice);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(strings.premiumTitle, style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: PremiumService.instance.entitlement,
          builder: (context, entitlement, _) {
            final expiresAt = entitlement.expiresAt;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Icon(
                  entitlement.active
                      ? Icons.verified_outlined
                      : Icons.auto_awesome_outlined,
                  color: const Color(0xFF7C5CFF),
                  size: 40,
                ),
                const SizedBox(height: 14),
                Text(
                  entitlement.active
                      ? strings.premiumActive
                      : strings.premiumPaywallTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entitlement.active && expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    strings.premiumExpires(expiresAt),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB9B9C2)),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    strings.premiumPaywallBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB9B9C2),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                _FeatureRow(
                  icon: Icons.summarize_outlined,
                  label: strings.isEnglish ? 'AI summaries' : 'AI 요약',
                ),
                _FeatureRow(
                  icon: Icons.manage_search_outlined,
                  label: strings.isEnglish ? 'Semantic search' : '말로 검색',
                ),
                _FeatureRow(
                  icon: Icons.block_outlined,
                  label: strings.isEnglish
                      ? 'No banner ads while Premium is active'
                      : '프리미엄 기간 광고 숨김',
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed:
                      _busy ||
                          entitlement.active ||
                          !PremiumPurchase.instance.available
                      ? null
                      : _subscribe,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    PremiumPurchase.instance.available
                        ? '${strings.premiumSubscribe} · $priceText'
                        : strings.premiumPrepared,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.restore),
                  label: Text(strings.premiumRestore),
                ),
                const SizedBox(height: 18),
                if (AdsService.instance.removeAds.value)
                  Text(
                    strings.premiumCouponNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFECECEC),
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  strings.premiumTermsNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9A9AA2),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C5CFF)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
