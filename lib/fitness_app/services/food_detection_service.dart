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
  static const String _token = '4f63df165dc3e0d3ce69f94be9f9db9de8f2124f';
  static const String _baseUrl = 'https://api.logmeal.es/v2';

  FoodDetectionService();

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
      // 1. Image Recognition (Dish)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/image/recognition/dish'),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imagePath,
        contentType: MediaType('image', 'jpeg'),
      ));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        print('LogMeal Error: $responseData');
        return _errorResult('API Error (${response.statusCode})');
      }

      final Map<String, dynamic> recognitionData = jsonDecode(responseData);
      final List dishes = recognitionData['recognition_results'] ?? [];
      
      if (dishes.isEmpty) {
        return FoodDetectionResult(
          label: 'Not food',
          estimatedCalories: 0,
          exerciseSuggestions: 'N/A',
        );
      }

      // Get the most likely dish
      final bestDish = dishes[0];
      final String dishName = bestDish['name'] ?? 'Unknown Dish';
      final int dishId = bestDish['id'];

      // 2. Get Nutritional Information
      final nutritionResponse = await http.post(
        Uri.parse('$_baseUrl/nutrition/dish/nutritional_info'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'dish_id': dishId}),
      );

      if (nutritionResponse.statusCode == 200) {
        final Map<String, dynamic> nutritionData = jsonDecode(nutritionResponse.body);
        final Map<String, dynamic> nutrients = nutritionData['nutritional_info'] ?? {};
        
        final double calories = _toDouble(nutrients['calories']);
        final Map<String, dynamic> totalNutrients = nutrients['totalNutrients'] ?? {};

        return FoodDetectionResult(
          label: dishName,
          estimatedCalories: calories,
          protein: _toDouble(totalNutrients['PROCNT']),
          carbs: _toDouble(totalNutrients['CHOCDF']),
          fat: _toDouble(totalNutrients['FAT']),
          exerciseSuggestions: _generateExerciseSuggestions(dishName, calories),
        );
      }

      return FoodDetectionResult(
        label: dishName,
        estimatedCalories: 0,
        exerciseSuggestions: 'Could not fetch nutritional info.',
      );

    } catch (e) {
      print('LogMeal System Error: $e');
      return _errorResult('Connection Error');
    }
  }

  FoodDetectionResult _errorResult(String message) {
    return FoodDetectionResult(
      label: message,
      estimatedCalories: 0,
      exerciseSuggestions: 'Please check your internet connection or API token.',
    );
  }

  String _generateExerciseSuggestions(String food, double calories) {
    if (calories <= 0) return "N/A";
    
    // Simple MET-based estimation (assuming 70kg person)
    // Run (10 MET): ~12.25 cal/min
    // Walk (3.5 MET): ~4.3 cal/min
    int runMin = (calories / 12.25).round();
    int walkMin = (calories / 4.3).round();

    return "To burn this $food, you'd need to run for ~$runMin min or walk for ~$walkMin min.";
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
