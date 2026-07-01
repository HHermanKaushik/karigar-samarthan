import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../providers/translations_provider.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import 'faq_screen.dart';

const String _whatsappNumber = '917350776098';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
        'https://wa.me/$_whatsappNumber?text=Hello%2C%20I%20need%20help%20with%20Karigar%20Samarthan.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open WhatsApp. Please check it is installed.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                tr('helpSupport'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SupportActionCard(
                  icon: Icons.chat_rounded,
                  iconColor: const Color(0xFF25D366), // WhatsApp green
                  title: tr('whatsappSupport'),
                  subtitle: tr('whatsappSupportSubtitle'),
                  onTap: () => _openWhatsApp(context),
                ),
                const SizedBox(height: 12),
                _SupportActionCard(
                  icon: Icons.smart_toy_outlined,
                  iconColor: AppColors.primary,
                  title: tr('askAiSupport'),
                  subtitle: tr('askAiSupportSubtitle'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showAppModal(context, child: const AiAssistantScreen());
                  },
                ),
                const SizedBox(height: 12),
                _SupportActionCard(
                  icon: Icons.quiz_outlined,
                  iconColor: AppColors.warning,
                  title: tr('browseAllFaqs'),
                  subtitle: tr('browseAllFaqsSubtitle'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showAppModal(context, child: const FaqScreen());
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
