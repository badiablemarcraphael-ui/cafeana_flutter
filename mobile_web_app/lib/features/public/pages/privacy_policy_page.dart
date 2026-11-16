import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

/// Public Privacy Policy & Account Deletion page required by Google Play Store
/// Data Safety & User Data policies. Accessible without authentication at
/// `/privacy` and `/delete-account`.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caféana? — Privacy Policy & Data Safety',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.landing),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Back to Home'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: cs.primary, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Privacy Policy & Account Data Deletion',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: November 2026 • Effective for Caféana? Mobile & Web Application (com.cafeana.cafeana_app)',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const Divider(height: 32),
                    const _SectionTitle('1. Information We Collect'),
                    const _SectionBody(
                      'Caféana? collects only the minimum information required to prepare your café orders and provide order status updates:\n'
                      '• Account Profile Data: Your display name and email address when you register or sign in via Email/Password or Google Sign-In.\n'
                      '• Order & Transaction History: Items ordered, customizations, order timestamps, and order fulfillment status.\n'
                      '• Optional Location Check: Used only when you actively verify proximity to the café during checkout (never tracked in the background).\n'
                      '• Push Notification Token: Used strictly to notify you when your drink or food order is queued, preparing, or ready for pickup.',
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('2. How We Use & Protect Your Data'),
                    const _SectionBody(
                      '• All data is encrypted in transit using HTTPS / TLS 1.3 and stored securely on Google Firebase infrastructure.\n'
                      '• We do NOT sell, rent, or share your personal information with third-party advertisers or data brokers.\n'
                      '• Your data is used solely for order fulfillment, digital receipts, customer support, and store service improvements.',
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('3. How to Delete Your Account & Personal Data'),
                    const _SectionBody(
                      'In compliance with Google Play Data Safety standards, you can permanently delete your Caféana? account and personal profile information at any time:\n\n'
                      'Option A — Inside the App or Website (Instant Deletion):\n'
                      '1. Sign in to your Caféana? account.\n'
                      '2. Open the "Profile" tab in the bottom navigation bar.\n'
                      '3. Scroll to "Account Actions" and tap "Delete My Account".\n'
                      '4. Confirm deletion. Your Firebase Authentication account is immediately deleted and your personal profile fields (name and email) are permanently anonymized.\n\n'
                      'Option B — Web Request Without the Mobile App:\n'
                      'Click the "Sign In to Delete Account" button below to sign in on the web and trigger immediate account deletion from your Profile page, or email our support team at support@cafeana.com with the subject "Account Deletion Request" from your registered email address (processed within 48 hours).',
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('4. Data Retention Policy'),
                    const _SectionBody(
                      '• Personal Identifiers (Display Name, Email Address, Auth UID): Deleted or anonymized immediately upon account deletion.\n'
                      '• Anonymized Accounting Receipts: Aggregated, non-identifiable order totals (with customer identity removed) are retained for store accounting and inventory records.',
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.login),
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: const Text('Sign In to Manage or Delete Account'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.landing),
                          icon: const Icon(Icons.local_cafe_outlined, size: 18),
                          label: const Text('Return to Caféana?'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.55,
        color: cs.onSurface.withValues(alpha: 0.88),
      ),
    );
  }
}
