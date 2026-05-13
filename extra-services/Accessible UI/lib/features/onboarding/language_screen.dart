import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../models/app_language.dart';
import '../../providers/language_provider.dart';

/// =========================
/// TTS SERVICE (LOCAL)
/// =========================
class TTSService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }
}

/// =========================
/// LANGUAGE SCREEN
/// =========================
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(languageProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEAE3FF),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo()),
                const SizedBox(height: 28),
                Text(
                  'Choose your language',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: AppLanguage.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final lang = AppLanguage.values[i];
                      final isActive = lang == selected;

                      return _LanguageCard(
                        lang: lang,
                        active: isActive,
                        onTap: () => ref
                            .read(languageProvider.notifier)
                            .setLanguage(lang),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// =========================
/// LANGUAGE CARD
/// =========================
class _LanguageCard extends StatelessWidget {
  final AppLanguage lang;
  final bool active;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.lang,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              // ICON CIRCLE
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(active ? 0.25 : 0.9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    lang.nativeName.characters.first,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // TEXT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.text,
                      ),
                    ),
                    Text(
                      lang.englishName,
                      style: TextStyle(
                        color: active ? Colors.white70 : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔊 SPEAKER BUTTON (NEW)
              IconButton(
                icon: Icon(
                  Icons.volume_up_outlined,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
                onPressed: () async {
                  await TTSService.speak(
                    text: _getSpeechText(lang),
                    languageCode: _getTtsCode(lang),
                  );
                },
              ),

              // CHECK ICON
              Icon(
                active ? Icons.check_circle : Icons.radio_button_unchecked,
                color: active ? Colors.white : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =========================
/// SPEECH TEXT (PER LANGUAGE)
/// =========================
String _getSpeechText(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.english:
      return "You have selected English";
    case AppLanguage.hindi:
      return "आपने हिन्दी चुनी है";
    case AppLanguage.marathi:
      return "तुम्ही मराठी निवडली आहे";
    case AppLanguage.bengali:
      return "আপনি বাংলা নির্বাচন করেছেন";
    case AppLanguage.tamil:
      return "நீங்கள் தமிழ் தேர்ந்தெடுத்துள்ளீர்கள்";
  }
}

/// =========================
/// TTS LANGUAGE CODE MAP
/// =========================
String _getTtsCode(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.english:
      return "en-US";
    case AppLanguage.hindi:
      return "hi-IN";
    case AppLanguage.marathi:
      return "mr-IN";
    case AppLanguage.bengali:
      return "bn-IN";
    case AppLanguage.tamil:
      return "ta-IN";
  }
}
