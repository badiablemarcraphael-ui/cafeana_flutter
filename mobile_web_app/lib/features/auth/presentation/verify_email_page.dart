import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_service.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/providers/firebase_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _isResending = false;

  Future<void> _checkVerification() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      await user.reload();
      // Reloading the user updates the underlying user object.
      // If verified, we can trigger the router to redirect by invalidating authStateChangesProvider.
      if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
         ref.invalidate(authStateChangesProvider);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email not verified yet. Please check your inbox.')),
          );
        }
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email resent!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'We\'ve sent a verification email to:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                ref.watch(firebaseAuthProvider).currentUser?.email ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'Please check your inbox and click the verification link to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _checkVerification,
                child: const Text('I have verified my email'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isResending ? null : _resendEmail,
                child: _isResending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Resend Verification Email'),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () async {
                  final confirm = await AppDialogs.confirm(
                    context,
                    title: 'Log Out',
                    message: 'Are you sure you want to cancel and log out?',
                    isDestructive: true,
                    confirmText: 'Log Out',
                  );
                  if (confirm) {
                    ref.read(authServiceProvider.notifier).signOut();
                  }
                },
                child: const Text('Cancel & Logout'),
              )
            ],
          ),
          ),
        ),
    );
  }
}
