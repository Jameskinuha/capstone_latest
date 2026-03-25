import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class FoodDetectionResult {
  final String label;
  final double estimatedCalories;
  final String exerciseSuggestions;
  final double protein;
  final double carbs;
  final double fat;

  FoodDetectionResult({
    required this.label,
    required this.estimatedCalories,
    required this.exerciseSuggestions,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });
}

class FoodDetectionService {
  // Use the API key provided in the error logs/context
  static const String _apiKey = 'AIzaSyCV9MpwuDpNgje8_5QZXXkL5-3SB5zqba4';
  
  // Updated list of models to try
  final List<String> _modelsToTry = [
    'models/gemini-1.5-flash-latest',
    'models/gemini-1.5-pro-latest',
  ];

  FoodDetectionService();

  GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  Future<FoodDetectionResult?> detectFood(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return FoodDetectionResult(
        label: 'File Error',
        estimatedCalories: 0,
        exerciseSuggestions: 'Image not found.',
      );
    }

    try {
      final imageBytes = await file.readAsBytes();

      final prompt = '''
Identify what is in this image.

If it is food:
- Provide estimated calories and macros.

If it is NOT food:
- Clearly say "Not food" and describe the object.

Return ONLY JSON:

{
  "food": "Name or 'Not food'",
  "calories": 0,
  "protein_g": 0,
  "carbs_g": 0,
  "fat_g": 0,
  "exercise_suggestions": "If not food, say N/A"
}
''';

      // Detect MIME type based on file extension
      String mimeType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      }

// Build content with correct MIME type
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ])
      ];

      // Try each model until one works
      String lastError = '';
      for (String modelName in _modelsToTry) {
        try {
          print('Trying AI model: $modelName');
          final model = _createModel(modelName);
          final response = await model.generateContent(content);
          final text = response.text;

          if (text != null && text.isNotEmpty) {
            print('AI Response ($modelName): $text');
            
            final start = text.indexOf('{');
            final end = text.lastIndexOf('}');
            
            if (start != -1 && end != -1) {
              final jsonString = text.substring(start, end + 1);
              final Map<String, dynamic> data = jsonDecode(jsonString);
              
              return FoodDetectionResult(
                label: data['food'] ?? 'Unknown Item',
                estimatedCalories: _toDouble(data['calories']),
                protein: _toDouble(data['protein_g']),
                carbs: _toDouble(data['carbs_g']),
                fat: _toDouble(data['fat_g']),
                exerciseSuggestions: data['exercise_suggestions'] ?? "Exercise suggested based on calorie intake.",
              );
            }
          }
        } catch (e) {
          lastError = e.toString();
          print('FULL ERROR: $lastError');
        }
      }

      // If we reach here, all models failed
      return FoodDetectionResult(
        label: 'API Error',
        estimatedCalories: 0,
        exerciseSuggestions: 'All AI models failed. Last Error: $lastError. Ensure your API Key is valid at aistudio.google.com and check your internet.',
      );
    } catch (e) {
       print('System Error: $e');
       return FoodDetectionResult(
        label: 'Memory/System Error',
        estimatedCalories: 0,
        exerciseSuggestions: 'Device memory error during image processing. Try closing other apps.',
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
