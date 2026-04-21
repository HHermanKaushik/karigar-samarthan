import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';

import '../nav.dart';
import '../components/voice_button.dart';
import '../components/audio_prompt.dart';
import '../providers/app_state.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isTtsPlaying = false;

  final Map<String, Map<String, String>> _languageConfigs = {
    'English': {
      'text': 'You have selected English.',
      'locale': 'en-US',
    },
    'Hindi': {
      'text': 'आपने हिंदी चुनी है।',
      'locale': 'hi-IN',
    },
    'Marathi': {
      'text': 'तुम्ही मराठी निवडली आहे।',
      'locale': 'mr-IN',
    },
    'Bengali': {
      'text': 'আপনি বাংলা নির্বাচন করেছেন।',
      'locale': 'bn-IN',
    },
    'Tamil': {
      'text': 'நீங்கள் தமிழ் தேர்ந்தெடுத்துள்ளீர்கள்।',
      'locale': 'ta-IN',
    },
  };

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _speech.initialize();
    await _tts.setLanguage("en-US");
    // Set a completion handler to update the AudioPrompt UI
    _tts.setCompletionHandler(() {
      setState(() => _isTtsPlaying = false);
    });
  }

  Future<void> _speak(String text, {String locale = 'en-US'}) async {
    setState(() => _isTtsPlaying = true);
    await _tts.stop();
    await _tts.setLanguage(locale); // Set the specific language locale
    await _tts.speak(text);
  }

  // Future<void> _speak(String text, {String locale = 'en-US'}) async {
  //   setState(() => _isTtsPlaying = true);
  //   await _tts.stop();
  //   await _tts.setLanguage(locale); // Set the specific language locale
  //   await _tts.speak(text);
  // }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            final command = val.recognizedWords.toLowerCase();
            if (command.contains("english")) _selectLanguage("English");
            if (command.contains("hindi")) _selectLanguage("Hindi");
            if (command.contains("marathi")) _selectLanguage("Marathi");
            if (command.contains("bengali")) _selectLanguage("Bengali");
            if (command.contains("tamil")) _selectLanguage("Tamil");
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _selectLanguage(String langKey) async {
    final config = _languageConfigs[langKey];

    if (config != null) {
      // Update Global State
      Provider.of<AppState>(context, listen: false).setLanguage(
          langKey,
          config['locale']!
      );

      // Speak confirmation
      // await _speak(config['text']!, locale: config['locale']!);
      await _speak(config['text']!, locale: config['locale']!);
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              AudioPrompt(
                text: "Please select a language",
                isPlaying: _isTtsPlaying,
                // Default prompt is English
                onPlay: () => _speak("Please select your preferred language from the list below, or press the microphone to speak.", locale: 'en-US'),
              ),
              const SizedBox(height: 30),
              Text(
                'Select Language',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView(
                  children: [
                    _LanguageCard(
                      label: 'English',
                      nativeLabel: 'English',
                      onTap: () => _selectLanguage("English"),
                    ),
                    _LanguageCard(
                      label: 'Hindi',
                      nativeLabel: 'हिन्दी',
                      onTap: () => _selectLanguage("Hindi"),
                    ),
                    _LanguageCard(
                      label: 'Marathi',
                      nativeLabel: 'मराठी',
                      onTap: () => _selectLanguage("Marathi"),
                    ),
                    _LanguageCard(
                      label: 'Bengali',
                      nativeLabel: 'বাংলা',
                      onTap: () => _selectLanguage("Bengali"),
                    ),
                    _LanguageCard(
                      label: 'Tamil',
                      nativeLabel: 'தமிழ்',
                      onTap: () => _selectLanguage("Tamil"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              VoiceButton(
                onTap: _listen,
                isListening: _isListening,
                label: _isListening ? "Listening..." : "Tap to Speak",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String label;
  final String nativeLabel;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.label,
    required this.nativeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volume_up, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
