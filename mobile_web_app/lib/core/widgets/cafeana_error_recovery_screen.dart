import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'app_background.dart';

/// A friendly, user-first error recovery screen that prevents "dead screen" states
/// when an unexpected runtime or routing error occurs.
class CafeanaErrorRecoveryScreen extends StatefulWidget {
  const CafeanaErrorRecoveryScreen({
    super.key,
    this.errorMessage,
    this.onRetry,
    this.showHomeButton = true,
  });

  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showHomeButton;

  @override
  State<CafeanaErrorRecoveryScreen> createState() =>
      _CafeanaErrorRecoveryScreenState();
}

class _CafeanaErrorRecoveryScreenState
    extends State<CafeanaErrorRecoveryScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primarySeed.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Icon badge ──────────────────────────────────────────
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8E8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF8B4B4),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.coffee_maker_rounded,
                            size: 40,
                            color: Color(0xFFBA1A1A),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Title ───────────────────────────────────────────────
                      Text(
                        'Oops! A Quick Hiccup',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primarySeed,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Friendly Subtitle ───────────────────────────────────
                      Text(
                        'We ran into an unexpected issue while loading this page. Don\'t worry, your data and orders are safe!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: AppTheme.primarySeed.withValues(alpha: 0.7),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Action Buttons ──────────────────────────────────────
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              if (widget.onRetry != null) {
                                widget.onRetry!();
                              } else if (context.mounted) {
                                context.go('/');
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (widget.showHomeButton)
                            OutlinedButton.icon(
                              onPressed: () {
                                if (context.mounted) {
                                  context.go('/');
                                }
                              },
                              icon: const Icon(Icons.home_outlined, size: 18),
                              label: const Text('Go to Home'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primarySeed,
                                side: BorderSide(
                                  color: AppTheme.primarySeed.withValues(alpha: 0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // ── Optional Developer / Debug Details Toggle ───────────
                      if (widget.errorMessage != null && (kDebugMode || _showDetails)) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showDetails = !_showDetails;
                            });
                          },
                          child: Text(
                            _showDetails ? 'Hide Details' : 'Show Error Details',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ),
                        if (_showDetails)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F7F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primarySeed.withValues(alpha: 0.1),
                              ),
                            ),
                            child: SelectableText(
                              widget.errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFF7E2A2A),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
