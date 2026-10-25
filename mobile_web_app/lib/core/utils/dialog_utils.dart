import 'package:flutter/material.dart';

class AppDialogs {
  /// Shows a styled confirmation dialog (e.g. "Are you sure you want to delete?")
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
              color: isDestructive ? cs.error : cs.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a success or neutral notification at the bottom of the screen
  static void showNotice(BuildContext context, String message, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? cs.error : cs.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }
}
