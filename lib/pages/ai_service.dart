import 'dart:io';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiProductResult {
  final String title;
  final String description;
  final String category;

  AiProductResult({
    required this.title,
    required this.description,
    required this.category,
  });
}

class AiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<AiProductResult?> processAndAnalyzeImage(File originalFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/temp_ai_resize_${DateTime.now().millisecondsSinceEpoch}.jpg';

      var compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );

      if (compressedFile == null) return null;
      return _analyzeImageWithGemini(File(compressedFile.path));
    } catch (e) {
      return null;
    }
  }

  static Future<AiProductResult?> _analyzeImageWithGemini(File imageFile) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = TextPart(
        "Act as an e-commerce assistant listing this item for sale. "
            "Analyze the image and generate a sales listing. "
            "Return a single JSON object with these exact keys:\n"
            "- 'title': A short, clear product name (max 5 words).\n"
            "- 'description': ONE attractive sentence describing the item's utility or material. "
            "Do NOT describe the background, lighting, timestamp, or camera angle. Keep it under 15 words.\n"
            "- 'category': A standard e-commerce category.\n"
            "Do not include any other text or markdown.",
      );

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', imageBytes)]),
      ]);

      if (response.text != null) {
        String cleanText = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        print("AI Raw Response HHHHHHHHHHHHHHHHHHHHHHHHH!!!!!!!!!!!!!!!!!!!!!!!: ${response.text}");
        final Map<String, dynamic> data = jsonDecode(cleanText);

        return AiProductResult(
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
        );
      }
    } catch (e) {
      print("AI Error: $e");
    }
    return null;
  }
}