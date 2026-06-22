import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Friendly, full-screen "no internet" state.
///
/// Designed for tech-illiterate users: a clear icon, short plain-language
/// message, and a single big "Try Again" button. Use this whenever a screen
/// needs data from the network and has nothing useful to show without it.
///
/// For transient failures (e.g. a background sync that failed but the
/// screen still has local data to show), prefer [showNetworkErrorSnackBar]
/// instead of replacing the whole screen.
class NetworkErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const NetworkErrorView({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a short, friendly snackbar for transient connectivity failures
/// (e.g. a background sync that couldn't reach the server). Use this when
/// the user's action still succeeded locally and they don't need to be
/// blocked.
void showNetworkErrorSnackBar(
  BuildContext context, {
  String message =
      "You're offline. We'll save this on your device and sync once "
          "you're back online.",
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
    ),
  );
}
