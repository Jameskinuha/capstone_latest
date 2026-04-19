import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class FoodMatch {
  final String name;
  final double confidence;

  FoodMatch({required this.name, required this.confidence});
}

class FoodDetectionResult {
  final String label;
  final double estimatedCalories;
  final String exerciseSuggestions;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> ingredients;
  final List<FoodMatch> allMatches;

  FoodDetectionResult({
    required this.label,
    required this.estimatedCalories,
    required this.exerciseSuggestions,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.ingredients = const [],
    this.allMatches = const [],
  });
}

class FoodDetectionService {
  static const String _token = 'b025576392d37d0a97f9ae240e67b401436f802e';
  static const String _baseUrl = 'https://api.logmeal.es/v2';

  FoodDetectionService();

  Future<FoodDetectionResult?> detectFood(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return _errorResult('File Error', 'Image file not found.');

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/image/recognition/complete'));
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(await http.MultipartFile.fromPath('image', imagePath, contentType: MediaType('image', 'jpeg')));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        return _handleApiError(response.statusCode, responseData);
      }

      final Map<String, dynamic> data = jsonDecode(responseData);
      final int? imageId = data['imageId'] ?? data['img_id'];
      
      if (imageId == null) return _errorResult('Scan Failed', 'Could not process image.');

      final List recognitionResults = data['recognition_results'] ?? [];
      if (recognitionResults.isEmpty) return _errorResult('No food detected', 'Try a clearer photo.');

      // Capture all valid matches (over 15% confidence)
      final List<FoodMatch> matches = recognitionResults
          .where((m) => (m['prob'] ?? 0.0) >= 0.15)
          .map((m) => FoodMatch(
                name: m['name'] ?? 'Unknown',
                confidence: (m['prob'] ?? 0.0).toDouble(),
              ))
          .toList();

      if (matches.isEmpty) return _errorResult('Unsure', 'AI confidence too low.');

      final results = await Future.wait([
        _getNutritionalInfo(imageId),
        _getIngredients(imageId),
      ]);

      final nutrition = results[0] as Map<String, dynamic>;
      final ingredientsList = results[1] as List<String>;

      final nutritionalInfo = nutrition['nutritional_info'];
      Map<String, dynamic>? targetNutrients;

      if (nutritionalInfo is List && nutritionalInfo.isNotEmpty) {
        targetNutrients = nutritionalInfo[0] as Map<String, dynamic>;
      } else if (nutritionalInfo is Map<String, dynamic>) {
        targetNutrients = nutritionalInfo;
      }

      if (targetNutrients == null) return _errorResult('No Data', 'Found food but no nutrition data.');

      final double calories = _toDouble(targetNutrients['calories'] ?? targetNutrients['ENERC_KCAL']);
      final Map<String, dynamic> macros = (targetNutrients['totalNutrients'] ?? targetNutrients['nutrients'] ?? {}) as Map<String, dynamic>;

      return FoodDetectionResult(
        label: matches[0].name,
        estimatedCalories: calories,
        protein: _toDouble(macros['PROCNT'] ?? macros['protein']),
        carbs: _toDouble(macros['CHOCDF'] ?? macros['carbs']),
        fat: _toDouble(macros['FAT'] ?? macros['fat']),
        ingredients: ingredientsList,
        allMatches: matches,
        exerciseSuggestions: _generateExerciseSuggestions(matches[0].name, calories),
      );
    } catch (e) {
      debugPrint('Detection Error: $e');
      return _errorResult('Connection Error', 'Please check connection.');
    }
  }

  Future<Map<String, dynamic>> _getNutritionalInfo(int imageId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/nutrition/recipe/nutritionalInfo'),
      headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: jsonEncode({'imageId': imageId}),
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  Future<List<String>> _getIngredients(int imageId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/nutrition/recipe/ingredients'),
      headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: jsonEncode({'imageId': imageId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List ingredients = data['ingredients'] ?? [];
      return ingredients.map((i) => i['name'].toString()).toList();
    }
    return [];
  }

  FoodDetectionResult? _handleApiError(int statusCode, String body) {
    String message = 'API Error ($statusCode)';
    try {
      final errorJson = jsonDecode(body);
      message = errorJson['message'] ?? errorJson['detail'] ?? message;
    } catch (_) {}
    return _errorResult('Scan Failed', message);
  }

  String _generateExerciseSuggestions(String food, double calories) {
    if (calories <= 0) return "N/A";
    int runMin = (calories / 12.25).round();
    int walkMin = (calories / 4.3).round();
    return "To burn this $food, run for ~$runMin min or walk for ~$walkMin min.";
  }

  FoodDetectionResult _errorResult(String label, String suggestion) {
    return FoodDetectionResult(
      label: label,
      estimatedCalories: 0,
      exerciseSuggestions: suggestion,
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is Map) {
      final quantity = value['quantity'] ?? value['value'];
      if (quantity != null) return _toDouble(quantity);
      return 0.0;
    }
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
