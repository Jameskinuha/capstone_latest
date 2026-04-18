import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class FoodDetectionResult {
  final String label;
  final double estimatedCalories;
  final String exerciseSuggestions;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> ingredients;
  final String nutriScore;
  final List<String> alternativeLabels;

  FoodDetectionResult({
    required this.label,
    required this.estimatedCalories,
    required this.exerciseSuggestions,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.ingredients = const [],
    this.nutriScore = 'N/A',
    this.alternativeLabels = const [],
  });
}

class FoodDetectionService {
  static const String _token = 'b025576392d37d0a97f9ae240e67b401436f802e';
  static const String _baseUrl = 'https://api.logmeal.es/v2';

  FoodDetectionService();

  /// Detects food using the 3-step workflow: Segmentation -> Ingredients -> Nutrition
  Future<FoodDetectionResult?> detectFood(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return _errorResult('File Error', 'Image file not found.');

    try {
      // 1. Recognize Image (Step 1: Complete Segmentation)
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/image/segmentation/complete'));
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(await http.MultipartFile.fromPath('image', imagePath, contentType: MediaType('image', 'jpeg')));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        return _handleApiError(response.statusCode, responseData);
      }

      final Map<String, dynamic> data = jsonDecode(responseData);
      final int? imageId = data['imageId'] ?? data['img_id'];
      
      if (imageId == null) return _errorResult('Scan Failed', 'Could not generate an Image ID.');

      // Get the detected segments
      final List segments = data['segmentation_results'] ?? [];
      if (segments.isEmpty) return _errorResult('No food detected', 'Try a clearer photo.');
      
      // To avoid "stacking" unrelated items, we pick the most prominent food item (the first segment)
      // This is more accurate for single-item photos
      final primarySegment = segments[0];
      final List recognitionResults = primarySegment['recognition_results'] ?? [];
      final String dishName = recognitionResults.isNotEmpty ? (recognitionResults[0]['name'] ?? 'Unknown food') : 'Unknown food';
      
      // 2 & 3. Fetch Ingredients and Nutrition in parallel using the imageId
      final results = await Future.wait([
        _getNutritionalInfo(imageId),
        _getIngredients(imageId),
      ]);

      final nutrition = results[0] as Map<String, dynamic>;
      final ingredients = results[1] as List<String>;

      // Parsing nutritional information
      // We look for the primary nutritional data to avoid "stacking" totals from background segments
      final nutritionalInfo = nutrition['nutritional_info'];
      Map<String, dynamic>? targetNutrients;

      if (nutritionalInfo is List && nutritionalInfo.isNotEmpty) {
        // Pick the first item's nutrients to match our primary label
        targetNutrients = nutritionalInfo[0] as Map<String, dynamic>;
      } else if (nutritionalInfo is Map<String, dynamic>) {
        targetNutrients = nutritionalInfo;
      }

      if (targetNutrients == null) return _errorResult('Parsing Error', 'Could not find nutritional data.');

      final double calories = _toDouble(targetNutrients['calories'] ?? targetNutrients['ENERC_KCAL']);
      final Map<String, dynamic> macros = (targetNutrients['totalNutrients'] ?? targetNutrients['nutrients'] ?? {}) as Map<String, dynamic>;

      return FoodDetectionResult(
        label: dishName,
        estimatedCalories: calories,
        protein: _toDouble(macros['PROCNT'] ?? macros['protein']),
        carbs: _toDouble(macros['CHOCDF'] ?? macros['carbs']),
        fat: _toDouble(macros['FAT'] ?? macros['fat']),
        ingredients: ingredients,
        nutriScore: nutrition['nutri_score']?.toString() ?? 'N/A',
        exerciseSuggestions: _generateExerciseSuggestions(dishName, calories),
      );
    } catch (e) {
      print('Detection Error: $e');
      return _errorResult('Connection Error', 'Please check your internet connection.');
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
    return "To burn this $food, you'd need to run for ~$runMin min or walk for ~$walkMin min.";
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
      if (quantity != null) {
        double val = _toDouble(quantity);
        final unit = value['unit']?.toString().toLowerCase();
        if (unit == 'kj') return val / 4.184;
        return val;
      }
      return 0.0;
    }

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
