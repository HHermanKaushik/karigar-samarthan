import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../nav.dart';
import '../providers/app_state.dart';
import '../components/action_card.dart';
import '../components/voice_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech.initialize();
  }

  Future<void> _speak(String text, String locale) async {
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  void _listen(String locale) async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: locale,
          onResult: (val) {
            if (val.finalResult) {
              final command = val.recognizedWords.toLowerCase();
              _handleCommand(command, locale);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  bool _hasWord(List<String> words, String text) {
    return words.any((w) => text.contains(w));
  }

  void _showHelp(String locale) {
    final helpText = locale.startsWith("hi")
        ? "आप कह सकते हैं: नया उत्पाद, मेरे आदेश, या प्रोफाइल"
        : "You can say: Add product, My orders, or Open profile.";
    _speak(helpText, locale);
  }

  void _handleCommand(String command, String locale) {
    final addWords = ["add", "create", "new", "upload", "जोड़", "नया"];
    final orderWords = ["order", "orders", "ऑर्डर", "आदेश"];
    final editWords = ["edit", "change", "update", "बदल", "सुधार"];
    final accountWords = ["account", "profile", "खाता", "प्रोफाइल"];
    final helpWords = ["help", "commands", "मदद", "क्या बोलूं"];

    if (_hasWord(addWords, command)) {
      _navigateTo(AppRoutes.addProduct, locale.startsWith("hi") ? "नया उत्पाद" : "Opening add product", locale);
    } else if (_hasWord(orderWords, command)) {
      _navigateTo(AppRoutes.myOrders, locale.startsWith("hi") ? "आपके आदेश" : "Opening orders", locale);
    } else if (_hasWord(editWords, command)) {
      _navigateTo(AppRoutes.editProducts, locale.startsWith("hi") ? "बदलाव करें" : "Opening editor", locale);
    } else if (_hasWord(accountWords, command)) {
      _navigateTo(AppRoutes.account, locale.startsWith("hi") ? "आपका खाता" : "Opening account", locale);
    } else if (_hasWord(helpWords, command)) {
      _showHelp(locale);
    } else {
      _speak(locale.startsWith("hi") ? "समझ नहीं आया" : "I didn't catch that", locale);
    }
    setState(() => _isListening = false);
  }

  void _navigateTo(String route, String feedbackText, String locale) async {
    await _speak(feedbackText, locale);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final String currentLang = appState.selectedLang;
    final String currentLocale = appState.locale;
    final bool isHi = currentLang == 'Hindi';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isHi ? 'नमस्ते, कारीगर' : 'Namaste, Artisan',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(isHi ? 'बताइये, क्या मदद करूँ?' : 'What would you like to do?',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: AssetImage('assets/images/Indian_artisan_working_brown_1769327616488.jpg'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  ActionCard(
                    icon: Icons.person_outline,
                    label: isHi ? 'मेरा खाता' : 'Edit My Account',
                    audioHint: isHi ? 'खाता' : 'Account',
                    // Updated: Tells the user WHAT to say
                    audioLabel: isHi ? 'बोलिए: "प्रोफाइल" या "खाता"' : 'Say: "Profile" or "Account"',
                    onTap: () => _navigateTo(AppRoutes.account, isHi ? "आपका खाता" : "Opening account", currentLocale),
                  ),
                  ActionCard(
                    icon: Icons.add_circle_outline,
                    label: isHi ? 'नया उत्पाद जोड़ें' : 'Add New Product',
                    audioHint: isHi ? 'नया' : 'New',
                    // Updated: Focuses on the "Add" action
                    audioLabel: isHi ? 'बोलिए: "नया उत्पाद" या "जोड़ें"' : 'Say: "New Product" or "Add"',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => _navigateTo(AppRoutes.addProduct, isHi ? "नया उत्पाद" : "Opening add product", currentLocale),
                  ),
                  ActionCard(
                    icon: Icons.edit_note,
                    label: isHi ? 'सामान की जानकारी बदलें' : 'Edit Products',
                    audioHint: isHi ? 'बदलाव' : 'Edit',
                    // Updated: Clear instructional hint
                    audioLabel: isHi ? 'बोलिए: "बदलाव" या "सुधार"' : 'Say: "Edit" or "Change"',
                    onTap: () => _navigateTo(AppRoutes.editProducts, isHi ? "बदलाव करें" : "Opening editor", currentLocale),
                  ),
                  ActionCard(
                    icon: Icons.shopping_bag_outlined,
                    label: isHi ? 'आए हुए ऑर्डर' : 'My Orders',
                    audioHint: isHi ? 'ऑर्डर' : 'Orders',
                    // Updated: Direct keyword hint
                    audioLabel: isHi ? 'बोलिए: "ऑर्डर" या "आदेश"' : 'Say: "Orders" or "My Orders"',
                    onTap: () => _navigateTo(AppRoutes.myOrders, isHi ? "आपके आदेश" : "Opening orders", currentLocale),
                  ),
                  ActionCard(
                    icon: Icons.help_outline_rounded,
                    label: isHi ? 'मदद और निर्देश' : 'Help & Commands',
                    audioHint: isHi ? 'मदद' : 'Help',
                    // Updated: Helping the user get help
                    audioLabel: isHi ? 'बोलिए: "मदद"' : 'Say: "Help"',
                    color: Colors.blueGrey,
                    onTap: () => _showHelp(currentLocale),
                  ),
                ],
              ),
            ),
              const SizedBox(height: 16),
              Center(
                child: VoiceButton(
                  onTap: () => _listen(currentLocale),
                  isListening: _isListening,
                  label: _isListening
                      ? (isHi ? "सुन रहा हूँ..." : "Listening...")
                      : (isHi ? "बोलिए: “नया उत्पाद”" : "Try saying: “Add product”"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}