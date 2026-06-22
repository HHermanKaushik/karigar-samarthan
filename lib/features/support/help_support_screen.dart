import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../providers/translations_provider.dart';
import '../ai_assistant/ai_assistant_screen.dart';

const String _supportPhoneNumber = '+91 1800 000 0000';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  Future<void> _callSupport(BuildContext context) async {
    final uri = Uri(
        scheme: 'tel', path: _supportPhoneNumber.replaceAll(' ', ''));
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Could not open the dialer. Please call $_supportPhoneNumber.'),
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
                  icon: Icons.call,
                  iconColor: AppColors.success,
                  title: tr('callSupport'),
                  subtitle:
                      '${tr('callSupportSubtitle')}: $_supportPhoneNumber',
                  onTap: () => _callSupport(context),
                ),
                const SizedBox(height: 12),
                _SupportActionCard(
                  icon: Icons.smart_toy_outlined,
                  iconColor: AppColors.primary,
                  title: tr('askAiSupport'),
                  subtitle: tr('askAiSupportSubtitle'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showAppModal(context,
                        child: const AiAssistantScreen());
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  tr('faq'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const _FaqTile(
                  question: 'How do I add a new product?',
                  answer:
                      'On the Home screen, tap "Add a New Product". Take or '
                      'choose a photo — the app will suggest a title, '
                      'description, category and tags. Review them, set the '
                      'price and quantity, then tap Publish.',
                ),
                const _FaqTile(
                  question: 'How do I change the app language?',
                  answer: 'Tap the profile icon at the bottom of the screen, '
                      'then "Change language" to choose English, Hindi, '
                      'Marathi, Bengali or Tamil.',
                ),
                const _FaqTile(
                  question: 'How do I see my orders?',
                  answer: 'Tap the receipt icon at the bottom of the screen to '
                      'see all customer orders, their status, and shipping '
                      'details.',
                ),
                const _FaqTile(
                  question: 'How do I set up or change my payment details?',
                  answer: 'During account setup you can add your UPI ID or '
                      'bank account so you get paid for your sales. Your '
                      'profile screen (tap the profile icon at the bottom) '
                      'shows whether payment setup is complete.',
                ),
                const _FaqTile(
                  question: "Why isn't my product showing a photo?",
                  answer:
                      'This can happen if the photo failed to upload due to '
                      'a weak internet connection. Try editing the product '
                      'and re-adding the photo when you have a stronger '
                      'connection.',
                ),
                const _FaqTile(
                  question: 'I have another problem. What should I do?',
                  answer: 'Tap "Ask the AI Assistant" above to speak or type '
                      'your question, or use "Call Support" to talk to our '
                      'team directly.',
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
                        style: const TextStyle(
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(question,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(answer,
              style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
