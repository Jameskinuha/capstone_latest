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
  static const String _token = 'b5efad4c670818631f35d63014dfe66dabf5d173';
  static const String _baseUrl = 'https://api.logmeal.es/v2';

  FoodDetectionService();

  /// Detects food from an image and fetches comprehensive nutritional data
  Future<FoodDetectionResult?> detectFood(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return _errorResult('Image not found');

    try {
      // 1. Image Recognition (Dish)
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/image/recognition/dish'));
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(await http.MultipartFile.fromPath('image', imagePath, contentType: MediaType('image', 'jpeg')));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      if (response.statusCode != 200) return _errorResult('API Error');

      final Map<String, dynamic> recognitionData = jsonDecode(responseData);
      final List dishes = recognitionData['recognition_results'] ?? [];
      if (dishes.isEmpty) return _errorResult('Not food');

      final bestDish = dishes[0];
      final int dishId = bestDish['id'];
      final String dishName = bestDish['name'] ?? 'Unknown';
      final List<String> alternatives = dishes.skip(1).take(3).map((d) => d['name'].toString()).toList();

      // 2. Fetch Multi-Feature Data in Parallel (Nutritional Info + Ingredients)
      final results = await Future.wait([
        _getNutritionalInfo(dishId),
        _getIngredients(dishId),
      ]);

      final nutrition = results[0] as Map<String, dynamic>;
      final ingredients = results[1] as List<String>;

      final Map<String, dynamic> nutrients = nutrition['nutritional_info'] ?? {};
      final double calories = _toDouble(nutrients['calories']);
      final Map<String, dynamic> totalNutrients = nutrients['totalNutrients'] ?? {};

      return FoodDetectionResult(
        label: dishName,
        estimatedCalories: calories,
        protein: _toDouble(totalNutrients['PROCNT']),
        carbs: _toDouble(totalNutrients['CHOCDF']),
        fat: _toDouble(totalNutrients['FAT']),
        ingredients: ingredients,
        nutriScore: nutrition['nutri_score']?.toString() ?? 'N/A',
        alternativeLabels: alternatives,
        exerciseSuggestions: _generateExerciseSuggestions(dishName, calories),
      );
    } catch (e) {
      return _errorResult('Connection Error');
    }
  }

  /// New Feature: Detect food via Barcode for packaged goods
  Future<FoodDetectionResult?> scanBarcode(String barcode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/barcode_scan'),
        headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
        body: jsonEncode({'barcode': barcode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Map barcode response to result (logic varies based on LogMeal's barcode schema)
        return FoodDetectionResult(
          label: data['product_name'] ?? 'Packaged Product',
          estimatedCalories: _toDouble(data['calories']),
          exerciseSuggestions: _generateExerciseSuggestions(data['product_name'], _toDouble(data['calories'])),
        );
      }
    } catch (e) {
      print('Barcode error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _getNutritionalInfo(int dishId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/nutrition/dish/nutritional_info'),
      headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: jsonEncode({'dish_id': dishId}),
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  Future<List<String>> _getIngredients(int dishId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recipe/ingredients'),
      headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: jsonEncode({'dish_id': dishId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List ingredients = data['ingredients'] ?? [];
      return ingredients.map((i) => i['name'].toString()).toList();
    }
    return [];
  }

  String _generateExerciseSuggestions(String food, double calories) {
    if (calories <= 0) return "N/A";
    int runMin = (calories / 12.25).round();
    int walkMin = (calories / 4.3).round();
    return "To burn this $food, you'd need to run for ~$runMin min or walk for ~$walkMin min.";
  }

  FoodDetectionResult _errorResult(String message) {
    return FoodDetectionResult(
      label: message,
      estimatedCalories: 0,
      exerciseSuggestions: 'Please check your connection.',
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
