import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'app_background.dart';

/// A branded, animated loading screen for Cafeana with built-in dead-screen prevention.
///
/// Features:
/// - Pulsing espresso cup logo with steam animations.
/// - Dynamic progress indicator and message.
/// - [timeoutSeconds] watchdog: If loading exceeds this duration (default 8s),
///   it reveals a recovery banner with "Retry" and "Go Home" actions,
///   guaranteeing the user is never trapped on an infinite, dead screen.
class CafeanaLoadingScreen extends StatefulWidget {
  const CafeanaLoadingScreen({
    super.key,
    this.message = 'Brewing your experience...',
    this.subtitle = 'Please wait while we prepare your café session.',
    this.onRetry,
    this.timeoutSeconds = 8,
    this.showBackButton = false,
  });

  final String message;
  final String subtitle;
  final VoidCallback? onRetry;
  final int timeoutSeconds;
  final bool showBackButton;

  @override
  State<CafeanaLoadingScreen> createState() => _CafeanaLoadingScreenState();
}

class _CafeanaLoadingScreenState extends State<CafeanaLoadingScreen> {
  Timer? _watchdogTimer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startWatchdog();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _timedOut = false;
    _watchdogTimer = Timer(Duration(seconds: widget.timeoutSeconds), () {
      if (mounted) {
        setState(() {
          _timedOut = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  void _handleReload() {
    if (kIsWeb) {
      // In web, trigger standard reload
      // Use router or reload
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        context.go('/');
      }
    } else {
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Animated Cup & Brand Mark ──────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient pulsating glow ring
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentColor.withValues(alpha: 0.15),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.15, 1.15),
                            duration: 1600.ms,
                            curve: Curves.easeInOut,
                          ),

                      // Outer rounded badge
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primarySeed.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.local_cafe_rounded,
                            size: 48,
                            color: AppTheme.accentColor,
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                begin: 0,
                                end: -6,
                                duration: 1200.ms,
                                curve: Curves.easeInOut,
                              ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Brand Title ────────────────────────────────────────────
                  Text(
                    'Caféana',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.primarySeed,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 8),

                  // ── Dynamic Message ────────────────────────────────────────
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primarySeed.withValues(alpha: 0.85),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.primarySeed.withValues(alpha: 0.6),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Progress indicator ─────────────────────────────────────
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Color(0xFFE8D5C4),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Dead-Screen Fallback Recovery ───────────────────────────
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 400),
                    crossFadeState: _timedOut
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(height: 48),
                    secondChild: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_tethering_error_rounded,
                                size: 20,
                                color: cs.error,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Taking longer than expected...',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primarySeed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _handleReload,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Try Again'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.go('/'),
                                icon: const Icon(Icons.home_rounded, size: 16),
                                label: const Text('Return to Home'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primarySeed,
                                  side: BorderSide(
                                    color: AppTheme.primarySeed.withValues(alpha: 0.3),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
