class AiProductSuggestion {
  final String title;
  final String category;
  final String description;
  final List<String> tags;

  const AiProductSuggestion({
    required this.title,
    required this.category,
    required this.description,
    required this.tags,
  });
}

abstract class AiAssistantService {
  Future<String> chat({
    required String message,
    required String languageCode,
  });

  Future<AiProductSuggestion> analyzeProduct({
    required List<String> imagePaths,
    required String voiceTranscript,
    required String languageCode,
  });
}

class StubAiAssistantService implements AiAssistantService {
  @override
  Future<String> chat({
    required String message,
    required String languageCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    return switch (languageCode) {
      'hi' =>
        'मैंने आपकी बात समझ ली। आप अपने उत्पाद की कीमत, विवरण और फोटो जोड़ सकते हैं।',
      'mr' => 'मी तुमचा संदेश समजलो. तुम्ही उत्पादनाची माहिती जोडू शकता.',
      'bn' => 'আমি আপনার বার্তা বুঝেছি। আপনি পণ্যের বিবরণ যোগ করতে পারেন।',
      'ta' => 'உங்கள் தகவலை புரிந்துகொண்டேன். தயாரிப்பு விவரங்களை சேர்க்கலாம்.',
      _ =>
        'I understood your request. You can continue editing your product listing.',
    };
  }

  @override
  Future<AiProductSuggestion> analyzeProduct({
    required List<String> imagePaths,
    required String voiceTranscript,
    required String languageCode,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    final text = voiceTranscript.toLowerCase();

    String category = 'Handicrafts';

    if (text.contains('shawl')) {
      category = 'Textiles';
    } else if (text.contains('rug')) {
      category = 'Home Decor';
    } else if (text.contains('jewellery')) {
      category = 'Jewellery';
    }

    return AiProductSuggestion(
      title: voiceTranscript.isEmpty
          ? 'Handmade Product'
          : voiceTranscript.split(' ').take(4).join(' '),
      category: category,
      description: voiceTranscript.isEmpty
          ? 'Beautiful handmade artisan product.'
          : voiceTranscript,
      tags: [
        'handmade',
        'artisan',
        category.toLowerCase(),
      ],
    );
  }
}
