import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Friendly, full-screen "no internet" state.
///
/// Designed for tech-illiterate users: a clear icon, short plain-language
/// message, and a single big "Try Again" button. Pass translated strings
/// from the caller via [title], [message], and [retryLabel].
///
/// For transient failures (e.g. a background sync that failed but the
/// screen still has local data to show), prefer [showNetworkErrorSnackBar]
/// instead of replacing the whole screen.
class NetworkErrorView extends StatelessWidget {
  final String? title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const NetworkErrorView({
    super.key,
    this.title,
    this.message,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title ?? 'No Internet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              message ??
                  'Please check your Wi-Fi or mobile data and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel ?? 'Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a short, friendly snackbar for transient connectivity failures.
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
