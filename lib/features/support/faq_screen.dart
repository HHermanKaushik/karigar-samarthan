import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../providers/language_provider.dart';
import '../../providers/translations_provider.dart';
import '../../services/service_providers.dart';

// ─── Multilingual FAQ content ─────────────────────────────────────────────────

class _FaqItem {
  final Map<String, String> question;
  final Map<String, String> answer;
  const _FaqItem({required this.question, required this.answer});

  String q(String code) => question[code] ?? question['en'] ?? '';
  String a(String code) => answer[code] ?? answer['en'] ?? '';
}

const _faqItems = [
  _FaqItem(
    question: {
      'en': 'How do I add a new product?',
      'hi': 'नया उत्पाद कैसे जोड़ें?',
      'mr': 'नवीन उत्पादन कसे जोडायचे?',
      'bn': 'নতুন পণ্য কীভাবে যোগ করব?',
      'ta': 'புதிய தயாரிப்பை எவ்வாறு சேர்ப்பது?',
    },
    answer: {
      'en':
          'On the Home screen, tap "Add a New Product". Take or choose a photo — '
          'the app will suggest a title, description, category and tags. Review them, '
          'set the price and quantity, then tap Publish.',
      'hi':
          'होम स्क्रीन पर "नया उत्पाद जोड़ें" टैप करें। फोटो लें या चुनें — ऐप '
          'शीर्षक, विवरण, श्रेणी और टैग सुझाएगा। उन्हें जांचें, कीमत और मात्रा सेट '
          'करें, फिर प्रकाशित करें।',
      'mr':
          'होम स्क्रीनवर "नवीन उत्पादन जोडा" टॅप करा. फोटो घ्या किंवा निवडा — '
          'अ‍ॅप शीर्षक, वर्णन, श्रेणी आणि टॅग सुचवेल. त्यांची तपासणी करा, किंमत '
          'आणि प्रमाण सेट करा, मग प्रकाशित करा.',
      'bn':
          'হোম স্ক্রিনে "নতুন পণ্য যোগ করুন" ট্যাপ করুন। ছবি তুলুন বা বেছে নিন — '
          'অ্যাপ শিরোনাম, বিবরণ, বিভাগ ও ট্যাগ সাজেস্ট করবে। সেগুলো দেখুন, দাম ও '
          'পরিমাণ সেট করুন, তারপর প্রকাশ করুন।',
      'ta':
          'முகப்புத் திரையில் "புதிய தயாரிப்பைச் சேர்க்கவும்" என்பதை தட்டவும். '
          'புகைப்படம் எடுக்கவும் அல்லது தேர்ந்தெடுக்கவும் — பயன்பாடு தலைப்பு, '
          'விவரிப்பு, வகை மற்றும் குறிச்சொற்களை பரிந்துரைக்கும். அவற்றை '
          'மதிப்பாய்வு செய்யுங்கள், விலை மற்றும் அளவை அமைத்து, வெளியிடு என்பதை '
          'தட்டவும்.',
    },
  ),
  _FaqItem(
    question: {
      'en': 'How do I change the app language?',
      'hi': 'ऐप की भाषा कैसे बदलें?',
      'mr': 'अ‍ॅपची भाषा कशी बदलायची?',
      'bn': 'অ্যাপের ভাষা কীভাবে পরিবর্তন করব?',
      'ta': 'பயன்பாட்டின் மொழியை எவ்வாறு மாற்றுவது?',
    },
    answer: {
      'en':
          "Tap the profile icon at the bottom of the screen, then tap "
          "'Change language' to choose English, Hindi, Marathi, Bengali or Tamil.",
      'hi':
          'स्क्रीन के नीचे प्रोफ़ाइल आइकन टैप करें, फिर "भाषा बदलें" टैप करके '
          'अंग्रेज़ी, हिंदी, मराठी, बंगाली या तमिल चुनें।',
      'mr':
          "स्क्रीनच्या तळाशी असलेल्या प्रोफाइल आयकॉनवर टॅप करा, नंतर "
          "'भाषा बदला' टॅप करून इंग्रजी, हिंदी, मराठी, बंगाली किंवा तमिळ निवडा.",
      'bn':
          "স্ক্রিনের নিচে প্রোফাইল আইকনে ট্যাপ করুন, তারপর 'ভাষা পরিবর্তন করুন' "
          'ট্যাপ করে ইংরেজি, হিন্দি, মারাঠি, বাংলা বা তামিল বেছে নিন।',
      'ta':
          "திரையின் கீழே உள்ள சுயவிவர ஐகானை தட்டவும், பிறகு 'மொழியை மாற்றவும்' "
          'என்பதை தட்டி ஆங்கிலம், இந்தி, மராத்தி, வங்காளம் அல்லது தமிழ் '
          'தேர்ந்தெடுக்கவும்.',
    },
  ),
  _FaqItem(
    question: {
      'en': 'How do I see my orders?',
      'hi': 'अपने ऑर्डर कैसे देखें?',
      'mr': 'माझे ऑर्डर कसे पाहायचे?',
      'bn': 'আমার অর্ডার কীভাবে দেখব?',
      'ta': 'என் ஆர்டர்களை எப்படி பார்ப்பது?',
    },
    answer: {
      'en':
          'Tap the receipt icon at the bottom of the screen to see all customer '
          'orders, their status, and shipping details.',
      'hi':
          'स्क्रीन के नीचे रिसीट आइकन टैप करें। सभी ग्राहक ऑर्डर, उनकी स्थिति '
          'और शिपिंग जानकारी देखें।',
      'mr':
          'सर्व ग्राहक ऑर्डर, त्यांची स्थिती आणि शिपिंग माहिती पाहण्यासाठी '
          'स्क्रीनच्या तळाशी असलेल्या रिसीट आयकॉनवर टॅप करा.',
      'bn':
          'সব গ্রাহক অর্ডার, তাদের অবস্থা এবং শিপিং তথ্য দেখতে স্ক্রিনের নিচে '
          'রিসিট আইকনে ট্যাপ করুন।',
      'ta':
          'அனைத்து வாடிக்கையாளர் ஆர்டர்கள், அவற்றின் நிலை மற்றும் ஷிப்பிங் '
          'விவரங்களை பார்க்க திரையின் கீழே உள்ள ரசீது ஐகானை தட்டவும்.',
    },
  ),
  _FaqItem(
    question: {
      'en': 'How do I set up my payment details?',
      'hi': 'भुगतान विवरण कैसे सेट करें?',
      'mr': 'पेमेंट तपशील कसा सेट करायचा?',
      'bn': 'পেমেন্টের তথ্য কীভাবে সেট করব?',
      'ta': 'பணம் செலுத்தும் விவரங்களை எவ்வாறு அமைப்பது?',
    },
    answer: {
      'en':
          'During account setup you can add your UPI ID or bank account so you '
          'get paid for your sales. Your profile screen shows whether payment '
          'setup is complete.',
      'hi':
          'खाता सेटअप के दौरान अपना UPI ID या बैंक खाता जोड़ें ताकि बिक्री का '
          'भुगतान मिले। प्रोफ़ाइल स्क्रीन पर देखें कि भुगतान सेटअप पूरा हुआ है।',
      'mr':
          'खाते सेटअप दरम्यान तुमचा UPI ID किंवा बँक खाते जोडा जेणेकरून '
          'विक्रीचे पेमेंट मिळेल. प्रोफाइल स्क्रीनवर पेमेंट सेटअप पूर्ण झाले '
          'की नाही ते पाहा.',
      'bn':
          'অ্যাকাউন্ট সেটআপের সময় আপনার UPI ID বা ব্যাংক অ্যাকাউন্ট যোগ করুন '
          'যাতে বিক্রির অর্থ পান। প্রোফাইল স্ক্রিনে দেখুন পেমেন্ট সেটআপ '
          'সম্পন্ন হয়েছে কি না।',
      'ta':
          'கணக்கு அமைவின் போது உங்கள் UPI ID அல்லது வங்கி கணக்கை சேர்க்கவும், '
          'இதனால் விற்பனைக்கு பணம் கிடைக்கும். சுயவிவர திரையில் பணம் செலுத்தும் '
          'அமைவு முடிந்துள்ளதா என்று பார்க்கவும்.',
    },
  ),
  _FaqItem(
    question: {
      'en': "Why isn't my product showing a photo?",
      'hi': 'मेरे उत्पाद में फोटो क्यों नहीं दिख रही?',
      'mr': 'माझ्या उत्पादनात फोटो का दिसत नाही?',
      'bn': 'আমার পণ্যে ছবি কেন দেখাচ্ছে না?',
      'ta': 'என் தயாரிப்பில் புகைப்படம் ஏன் காட்டவில்லை?',
    },
    answer: {
      'en':
          'This can happen if the photo failed to upload due to a weak internet '
          'connection. Try editing the product and re-adding the photo when you '
          'have a stronger connection.',
      'hi':
          'कमज़ोर इंटरनेट के कारण फोटो अपलोड न हो तो यह हो सकता है। मज़बूत '
          'कनेक्शन पर उत्पाद संपादित करके फोटो दोबारा जोड़ें।',
      'mr':
          'कमकुवत इंटरनेट कनेक्शनमुळे फोटो अपलोड न झाल्यास असे होऊ शकते. '
          'चांगले कनेक्शन असताना उत्पादन संपादित करून फोटो पुन्हा जोडा.',
      'bn':
          'দুর্বল ইন্টারনেটের কারণে ছবি আপলোড না হলে এটা হতে পারে। ভালো '
          'সংযোগে পণ্য সম্পাদনা করে ছবি আবার যোগ করুন।',
      'ta':
          'பலவீனமான இணைப்பால் புகைப்படம் பதிவேற்றம் ஆகாவிட்டால் இது நடக்கலாம். '
          'வலுவான இணைப்பில் தயாரிப்பை திருத்தி புகைப்படத்தை மீண்டும் சேர்க்கவும்.',
    },
  ),
  _FaqItem(
    question: {
      'en': 'I have another problem. What should I do?',
      'hi': 'मुझे कोई और समस्या है। क्या करूं?',
      'mr': 'मला आणखी एक समस्या आहे. काय करावे?',
      'bn': 'আমার আরেকটা সমস্যা আছে। কী করব?',
      'ta': 'வேறு பிரச்சனை உள்ளது. என்ன செய்வது?',
    },
    answer: {
      'en':
          "Tap 'Ask the AI Assistant' in Help & Support to speak or type your "
          "question in your own language, or tap 'Chat on WhatsApp' to reach "
          'our support team directly.',
      'hi':
          '"मदद और समर्थन" में "AI सहायक से पूछें" टैप करके अपनी भाषा में बोलें '
          'या टाइप करें, या सीधे हमारी टीम तक पहुंचने के लिए "WhatsApp पर चैट '
          'करें" टैप करें।',
      'mr':
          '"मदत आणि समर्थन" मध्ये "AI सहाय्यकाला विचारा" टॅप करून तुमच्या '
          'भाषेत बोला किंवा टाइप करा, किंवा आमच्या टीमपर्यंत थेट पोहोचण्यासाठी '
          '"WhatsApp वर चॅट करा" टॅप करा.',
      'bn':
          '"সাহায্য ও সহায়তা"-তে "AI সহকারীকে জিজ্ঞেস করুন" ট্যাপ করে আপনার '
          'ভাষায় বলুন বা টাইপ করুন, অথবা সরাসরি আমাদের দলের সাথে যোগাযোগ '
          'করতে "WhatsApp এ চ্যাট করুন" ট্যাপ করুন।',
      'ta':
          '"உதவி & ஆதரவு"-ல் "AI உதவியாளரிடம் கேளுங்கள்" என்பதை தட்டி உங்கள் '
          'மொழியில் பேசுங்கள் அல்லது தட்டச்சு செய்யுங்கள், அல்லது எங்கள் குழுவை '
          'நேரடியாக அடைய "WhatsApp இல் அரட்டை" என்பதை தட்டவும்.',
    },
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  final _searchController = TextEditingController();
  final _recorder = FlutterSoundRecorder();

  String _searchQuery = '';
  bool _listening = false;
  bool _transcribing = false;
  bool _recorderReady = false;
  String? _recordingPath;
  _FaqItem? _playingItem;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recorder.closeRecorder();
    TTSService.stop();
    super.dispose();
  }

  List<_FaqItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _faqItems;
    final lang = ref.read(languageProvider);
    final lower = _searchQuery.toLowerCase();
    return _faqItems.where((item) {
      return item.q(lang.code).toLowerCase().contains(lower) ||
          item.a(lang.code).toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> _playAnswer(_FaqItem item) async {
    if (_playingItem == item) {
      await TTSService.stop();
      if (mounted) setState(() => _playingItem = null);
      return;
    }
    await TTSService.stop();
    if (mounted) setState(() => _playingItem = item);

    final lang = ref.read(languageProvider);
    await TTSService.speak(
      text: item.a(lang.code),
      languageCode: lang.sarvamCode,
      onComplete: () {
        if (mounted) setState(() => _playingItem = null);
      },
    );
  }

  Future<void> _toggleVoiceSearch() async {
    if (_listening) {
      await _stopAndTranscribe();
      return;
    }
    if (!_recorderReady) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;
      await _recorder.openRecorder();
      if (mounted) setState(() => _recorderReady = true);
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/ks_faq_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );
    if (mounted) setState(() => _listening = true);
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stopRecorder();
    if (mounted) setState(() { _listening = false; _transcribing = path != null; });

    if (path == null) return;

    final lang = ref.read(languageProvider);
    final sarvam = ref.read(sarvamServiceProvider);

    final result = await sarvam.speechToText(
      audioFile: File(path),
      languageCode: lang.sarvamCode,
    );

    if (!mounted) return;
    setState(() => _transcribing = false);

    if (result != null && result.transcript.isNotEmpty) {
      _searchController.text = result.transcript;
      setState(() => _searchQuery = result.transcript);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final filtered = _filteredItems;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                tr('faq'),
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
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: tr('searchFaqs'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              VoiceButton(
                size: 44,
                listening: _listening,
                onTap: _toggleVoiceSearch,
              ),
            ],
          ),
          if (_transcribing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('listening'),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          // FAQ list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      tr('noFaqResults'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return _FaqTile(
                        item: item,
                        listenLabel: tr('listenToAnswer'),
                        isPlaying: _playingItem == item,
                        onPlay: () => _playAnswer(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _FaqTile extends ConsumerWidget {
  final _FaqItem item;
  final String listenLabel;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _FaqTile({
    required this.item,
    required this.listenLabel,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(item.q(lang.code),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            item.a(lang.code),
            style: const TextStyle(
                color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPlay,
              icon: Icon(
                isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                size: 18,
              ),
              label: Text(isPlaying ? '...' : listenLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
