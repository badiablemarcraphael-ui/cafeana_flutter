import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/providers/auth_service.dart';
import '../../../core/widgets/gradient_button.dart';

/// Combined Login / Register screen using a [DefaultTabController].
///
/// - Login tab: email + password form + Forgot Password + Google Sign-In
/// - Register tab: name + email + password + confirm password form + Google Sign-In
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    // Show errors as a SnackBar
    ref.listen<AsyncValue<void>>(authServiceProvider, (_, state) {
      if (state case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_friendlyError(error))),
                ],
              ),
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(16),
            ),
          );
        ref.read(authServiceProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: ScrollConfiguration(
                // Hide the scrollbar completely
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      minHeight: size.height * 0.6,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),

                        // ── Branding ─────────────────────────────────────
                        _LogoSection()
                            .animate()
                            .scale(
                                duration: 600.ms, curve: Curves.easeOutBack)
                            .fadeIn(duration: 400.ms),

                        const SizedBox(height: 48),

                        // ── Glass Card ────────────────────────────────────
                        _AuthCard(
                          tabController: _tabController,
                          currentTab: _currentTab,
                          isLoading: authState.isLoading,
                        )
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 400.ms)
                            .slideY(begin: 0.08, end: 0, delay: 500.ms),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('user-not-found')) return 'No account found for this email.';
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'An account already exists for this email.';
    }
    if (msg.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    }
    if (msg.contains('operation-not-allowed')) {
      return 'This sign-in method is disabled in Firebase Console.';
    }
    if (msg.contains('popup-closed-by-user') ||
        msg.contains('cancelled')) {
      return 'Sign-in cancelled.';
    }
    return 'Error: $msg';
  }
}

// ── Logo Section ──────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // ── Real Cafeana logo ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                blurRadius: 32,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/logo.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Your café, your way ✨',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.3,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}

// ── Auth Card ─────────────────────────────────────────────────────────────────

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.tabController,
    required this.currentTab,
    required this.isLoading,
  });

  final TabController tabController;
  final int currentTab;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2420).withValues(alpha: 0.95)
              : const Color(0xFFFFF8E7).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Custom tab bar ──────────────────────────────────────────────
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2420), Color(0xFF40342E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2C2420).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                dividerHeight: 0,
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Register'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Tab content ─────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: SizedBox(
                height: currentTab == 0 ? 390 : 500,
                child: TabBarView(
                  controller: tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _LoginForm(isLoading: isLoading),
                    _RegisterForm(isLoading: isLoading),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Login form ────────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({required this.isLoading});
  final bool isLoading;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authServiceProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passCtrl.text);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter your email first, then tap Forgot Password.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    await ref
        .read(authServiceProvider.notifier)
        .sendPasswordReset(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // ── Email ─────────────────────────────────────────────────────────
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 14),

          // ── Password ──────────────────────────────────────────────────────
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

          // ── Forgot password ───────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.isLoading ? null : _forgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                foregroundColor: cs.primary,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 12),

          // ── Sign In button ─────────────────────────────────────────────────
          GradientButton(
            onPressed: widget.isLoading ? null : _submit,
            isLoading: widget.isLoading,
            child: const Text('Sign In'),
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 20),

          // ── Divider ────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Divider(color: cs.outlineVariant, thickness: 0.8),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: cs.outlineVariant, thickness: 0.8),
              ),
            ],
          ).animate().fadeIn(delay: 180.ms),

          const SizedBox(height: 16),

          // ── Google Sign-In ─────────────────────────────────────────────────
          _GoogleSignInButton(isLoading: widget.isLoading)
              .animate()
              .fadeIn(delay: 210.ms)
              .slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }
}

// ── Register form ─────────────────────────────────────────────────────────────

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({required this.isLoading});
  final bool isLoading;

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authServiceProvider.notifier)
        .register(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 12),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 12),

            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Password must be ≥ 6 characters'
                  : null,
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 12),

            TextFormField(
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  v != _passCtrl.text ? 'Passwords do not match' : null,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            GradientButton(
              onPressed: widget.isLoading ? null : _submit,
              isLoading: widget.isLoading,
              child: const Text('Create Account'),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            // ── Divider ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                    child: Divider(color: cs.outlineVariant, thickness: 0.8)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or sign up with',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                    child: Divider(color: cs.outlineVariant, thickness: 0.8)),
              ],
            ).animate().fadeIn(delay: 270.ms),

            const SizedBox(height: 16),

            // ── Google Sign-In ─────────────────────────────────────────────
            _GoogleSignInButton(isLoading: widget.isLoading)
                .animate()
                .fadeIn(delay: 290.ms)
                .slideY(begin: 0.05, end: 0),
          ],
        ),
      ),
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────────────────────────

class _GoogleSignInButton extends ConsumerWidget {
  const _GoogleSignInButton({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () => ref
                .read(authServiceProvider.notifier)
                .signInWithGoogle(),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : cs.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF3C4043),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google 'G' logo using coloured text
            const _GoogleLogo(),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google logo (drawn with Text — no image needed) ───────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    // Simple coloured "G" logo using RichText
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue segment
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    // Red
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    // Yellow
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    // Green
    final greenPaint = Paint()..color = const Color(0xFF34A853);

    // Draw coloured arcs
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, 3.14, false, bluePaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        1.57, 1.57, false, greenPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, -1.57, false, yellowPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -3.14, 1.0, false, redPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);

    // White center circle
    canvas.drawCircle(center, radius * 0.5,
        Paint()..color = Colors.white..style = PaintingStyle.fill);

    // 'G' right horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - size.height * 0.1,
          radius * 0.85, size.height * 0.2),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

