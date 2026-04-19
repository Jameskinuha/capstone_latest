import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

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
  static const String _token = '4f63df165dc3e0d3ce69f94be9f9db9de8f2124f';
  static const String _baseUrl = 'https://api.logmeal.es/v2';

  // USDA FoodData Central API (free, full nutrition data)
  static const String _usdaApiKey = 'yND2GI87KLD99nD4x2aQRZiaguM896r3LkkOAyeT';
  static const String _nutritionApiUrl =
      'https://api.nal.usda.gov/fdc/v1/foods/search';

  // Filipino food nutrition table based on FNRI (Food and Nutrition Research
  // Institute of the Philippines) Philippine Food Composition Tables, 8th ed.
  // Values are per 100g edible portion.
  // Format: 'keyword': [calories, protein_g, carbs_g, fat_g]
  static const Map<String, List<double>> _filipinoFoodDb = {
    'adobo': [250, 16.0, 3.0, 19.0],
    'chicken adobo': [190, 18.0, 4.0, 11.0],
    'pork adobo': [250, 16.0, 3.0, 19.0],
    'sinigang': [90, 7.0, 5.0, 5.0],
    'kare kare': [140, 10.0, 6.0, 8.0],
    'kare-kare': [140, 10.0, 6.0, 8.0],
    'lechon': [320, 22.0, 0.0, 26.0],
    'lechon kawali': [380, 20.0, 5.0, 32.0],
    'crispy pata': [400, 25.0, 5.0, 32.0],
    'pancit': [150, 6.0, 20.0, 5.0],
    'pancit canton': [150, 6.0, 20.0, 5.0],
    'pancit bihon': [130, 5.0, 22.0, 3.0],
    'lumpia': [210, 8.0, 18.0, 12.0],
    'lumpiang shanghai': [220, 9.0, 16.0, 14.0],
    'sisig': [280, 18.0, 5.0, 21.0],
    'bicol express': [220, 12.0, 8.0, 16.0],
    'menudo': [150, 11.0, 8.0, 8.0],
    'caldereta': [180, 13.0, 7.0, 11.0],
    'tinola': [80, 9.0, 4.0, 3.0],
    'bulalo': [150, 12.0, 2.0, 10.0],
    'nilaga': [120, 10.0, 5.0, 7.0],
    'pinakbet': [100, 5.0, 8.0, 6.0],
    'laing': [180, 5.0, 8.0, 15.0],
    'dinuguan': [200, 14.0, 5.0, 14.0],
    'longganisa': [280, 14.0, 8.0, 22.0],
    'tocino': [250, 17.0, 14.0, 14.0],
    'tapsilog': [350, 22.0, 30.0, 14.0],
    'tapa': [280, 24.0, 8.0, 16.0],
    'sinangag': [180, 4.0, 30.0, 5.0],
    'fried rice': [180, 4.0, 30.0, 5.0],
    'halo-halo': [160, 3.0, 32.0, 3.0],
    'halo halo': [160, 3.0, 32.0, 3.0],
    'leche flan': [220, 5.0, 35.0, 7.0],
    'puto': [160, 4.0, 30.0, 3.0],
    'bibingka': [200, 4.0, 35.0, 5.0],
    'inihaw': [200, 20.0, 0.0, 13.0],
    'liempo': [350, 20.0, 0.0, 30.0],
    'bangus': [165, 22.0, 0.0, 8.0],
    'milkfish': [165, 22.0, 0.0, 8.0],
    'tilapia': [130, 26.0, 0.0, 3.0],
    'daing': [220, 28.0, 0.0, 12.0],
    'tortang talong': [130, 8.0, 6.0, 9.0],
    'arroz caldo': [100, 6.0, 14.0, 2.0],
    'lugaw': [75, 2.0, 15.0, 1.0],
    'champorado': [160, 3.0, 32.0, 3.0],
    'ginataan': [180, 2.0, 30.0, 6.0],
    'palabok': [180, 8.0, 24.0, 6.0],
    'batchoy': [120, 9.0, 12.0, 4.0],
    'mami': [110, 8.0, 12.0, 3.0],
    'siopao': [230, 9.0, 32.0, 7.0],
    'kwek kwek': [200, 10.0, 18.0, 10.0],
    'isaw': [180, 14.0, 8.0, 10.0],
    'balut': [188, 13.6, 11.9, 8.7],
    'dinugoan': [200, 14.0, 5.0, 14.0],
  };

  FoodDetectionService();

  Future<FoodDetectionResult?> detectFood(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists())
      return _errorResult('File Error', 'Image file not found.');

    try {
      // Compress image to avoid 413 (Request Entity Too Large)
      final compressedBytes = await _compressImage(file);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/image/recognition/complete'),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          compressedBytes,
          filename: 'food.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      debugPrint('LogMeal API status: ${response.statusCode}');
      debugPrint('LogMeal API response: $responseData');

      if (response.statusCode == 429) {
        return _errorResult(
          'Rate Limited',
          'LogMeal daily limit reached. Try again tomorrow or create a new API user token at logmeal.es.',
        );
      }

      if (response.statusCode != 200) {
        return _handleApiError(response.statusCode, responseData);
      }

      final Map<String, dynamic> data = jsonDecode(responseData);
      final int? imageId = data['imageId'] ?? data['img_id'];

      if (imageId == null)
        return _errorResult('Scan Failed', 'Could not process image.');

      final List recognitionResults = data['recognition_results'] ?? [];
      if (recognitionResults.isEmpty)
        return _errorResult('No food detected', 'Try a clearer photo.');

      // Capture all valid matches (over 15% confidence)
      final List<FoodMatch> matches = recognitionResults
          .where((m) => (m['prob'] ?? 0.0) >= 0.15)
          .map(
            (m) => FoodMatch(
              name: m['name'] ?? 'Unknown',
              confidence: (m['prob'] ?? 0.0).toDouble(),
            ),
          )
          .toList();

      if (matches.isEmpty)
        return _errorResult('Unsure', 'AI confidence too low.');

      final String foodName = matches[0].name;

      // Fetch nutrition from CalorieNinjas (accurate) + ingredients from LogMeal in parallel
      final results = await Future.wait([
        _getNutritionFromDatabase(foodName),
        _getIngredients(imageId),
      ]);

      final nutritionData = results[0] as Map<String, double>;
      final ingredientsList = results[1] as List<String>;

      double calories;
      double protein;
      double carbs;
      double fat;

      if (nutritionData.isNotEmpty) {
        // Primary: CalorieNinjas (USDA-backed, per-serving data)
        calories = nutritionData['calories'] ?? 0;
        protein = nutritionData['protein'] ?? 0;
        carbs = nutritionData['carbs'] ?? 0;
        fat = nutritionData['fat'] ?? 0;
        debugPrint(
          'Nutrition source: USDA — $foodName: ${calories.toStringAsFixed(1)} kcal',
        );
      } else {
        // Fallback: LogMeal nutrition (less accurate, recipe-level estimate)
        debugPrint('USDA unavailable, falling back to LogMeal nutrition');
        final nutrition = await _getNutritionalInfo(imageId);
        final nutritionalInfo = nutrition['nutritional_info'];
        Map<String, dynamic>? targetNutrients;

        if (nutritionalInfo is List && nutritionalInfo.isNotEmpty) {
          targetNutrients = nutritionalInfo[0] as Map<String, dynamic>;
        } else if (nutritionalInfo is Map<String, dynamic>) {
          targetNutrients = nutritionalInfo;
        }

        if (targetNutrients == null)
          return _errorResult('No Data', 'Found food but no nutrition data.');

        calories = _toDouble(
          targetNutrients['calories'] ?? targetNutrients['ENERC_KCAL'],
        );
        final Map<String, dynamic> macros =
            (targetNutrients['totalNutrients'] ??
                    targetNutrients['nutrients'] ??
                    {})
                as Map<String, dynamic>;
        protein = _toDouble(macros['PROCNT'] ?? macros['protein']);
        carbs = _toDouble(macros['CHOCDF'] ?? macros['carbs']);
        fat = _toDouble(macros['FAT'] ?? macros['fat']);
      }

      return FoodDetectionResult(
        label: foodName,
        estimatedCalories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        ingredients: ingredientsList,
        allMatches: matches,
        exerciseSuggestions: _generateExerciseSuggestions(foodName, calories),
      );
    } catch (e) {
      debugPrint('Detection Error: $e');
      return _errorResult('Connection Error', 'Please check connection.');
    }
  }

  /// Compress and resize image to stay under LogMeal's upload limit.
  Future<List<int>> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    return await compute(_resizeAndEncode, bytes);
  }

  static List<int> _resizeAndEncode(Uint8List bytes) {
    var image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Resize if wider than 1024px, maintaining aspect ratio
    if (image.width > 1024) {
      image = img.copyResize(image, width: 1024);
    }

    // Encode as JPEG with 80% quality
    return img.encodeJpg(image, quality: 80);
  }

  Future<Map<String, dynamic>> _getNutritionalInfo(int imageId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/nutrition/recipe/nutritionalInfo'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'imageId': imageId}),
    );
    return response.statusCode == 200 ? jsonDecode(response.body) : {};
  }

  /// Fetches accurate per-serving nutrition data.
  /// Checks local FNRI Filipino food table first, then falls back to USDA.
  Future<Map<String, double>> _getNutritionFromDatabase(String foodName) async {
    // 1. Check Filipino food database first (FNRI data)
    final filipinoResult = _lookupFilipinoFood(foodName);
    if (filipinoResult.isNotEmpty) {
      debugPrint(
        'FNRI match for "$foodName": ${filipinoResult['calories']} kcal',
      );
      return filipinoResult;
    }

    // 2. Fall back to USDA FoodData Central
    try {
      final url = Uri.parse(
        '$_nutritionApiUrl?query=${Uri.encodeComponent(foodName)}&pageSize=10&dataType=SR%20Legacy,Foundation&api_key=$_usdaApiKey',
      );
      final response = await http.get(url);

      debugPrint('USDA API status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List foods = data['foods'] ?? [];

        if (foods.isNotEmpty) {
          // Pick the best match — penalize processed/dry/powder forms
          // that don't represent what was actually scanned
          final food = _pickBestMatch(foodName, foods);
          final List nutrients = food['foodNutrients'] ?? [];

          double calories = 0, protein = 0, carbs = 0, fat = 0;

          for (final n in nutrients) {
            final name = (n['nutrientName'] ?? '').toString().toLowerCase();
            final unit = (n['unitName'] ?? '').toString().toUpperCase();
            final value = _toDouble(n['value']);
            if (name == 'energy' && unit == 'KCAL') {
              calories = value;
            } else if (name == 'protein') {
              protein = value;
            } else if (name.contains('carbohydrate')) {
              carbs = value;
            } else if (name == 'total lipid (fat)') {
              fat = value;
            }
          }

          debugPrint(
            'USDA match: "${food['description']}" → ${calories}kcal, ${protein}g protein, ${carbs}g carbs, ${fat}g fat',
          );

          return {
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
          };
        }
      } else {
        debugPrint('USDA API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('USDA Error: $e');
    }
    return {};
  }

  /// Looks up a food in the local FNRI Filipino food table.
  /// Returns nutrition map if a match is found, empty map otherwise.
  Map<String, double> _lookupFilipinoFood(String foodName) {
    final query = foodName.toLowerCase();

    // Exact match first
    if (_filipinoFoodDb.containsKey(query)) {
      final v = _filipinoFoodDb[query]!;
      return {'calories': v[0], 'protein': v[1], 'carbs': v[2], 'fat': v[3]};
    }

    // Partial match — check if any Filipino dish keyword appears in the food name
    for (final entry in _filipinoFoodDb.entries) {
      if (query.contains(entry.key) || entry.key.contains(query)) {
        final v = entry.value;
        debugPrint('FNRI partial match: "$query" → "${entry.key}"');
        return {'calories': v[0], 'protein': v[1], 'carbs': v[2], 'fat': v[3]};
      }
    }

    return {};
  }

  /// Scores USDA results and picks the best match for the scanned food.
  /// Prefers cooked/raw generic items over dried, powdered, or branded variants.
  Map<String, dynamic> _pickBestMatch(String query, List foods) {
    final queryWords = query.toLowerCase().split(' ');
    // Words that indicate a processed/unnatural form unlikely to match a scanned food
    const penaltyWords = [
      'dehydrated',
      'dried',
      'powder',
      'flour',
      'dry',
      'unenriched',
      'enriched',
      'frozen',
      'canned',
      'mix',
    ];
    // Complex dish words — penalise when NOT already in the original query
    const dishWords = [
      'salad',
      'sandwich',
      'burger',
      'soup',
      'pizza',
      'casserole',
      'stew',
      'wrap',
      'taco',
      'burrito',
      'meal',
    ];

    int bestScore = -999;
    dynamic bestFood = foods[0];

    for (final food in foods) {
      final desc = (food['description'] ?? '').toString().toLowerCase();
      int score = 0;

      // Reward query words found in description
      for (final word in queryWords) {
        if (desc.contains(word)) score += 10;
      }

      // Penalize processed/uncooked forms
      for (final word in penaltyWords) {
        if (desc.contains(word)) score -= 8;
      }

      // Penalize complex dish types not in the original query
      for (final word in dishWords) {
        if (desc.contains(word) && !query.toLowerCase().contains(word)) {
          score -= 10;
        }
      }

      // Reward cooking method words in description (only if not already a query word)
      const cookedWords = [
        'cooked',
        'grilled',
        'baked',
        'fried',
        'boiled',
        'roasted',
        'steamed',
      ];
      for (final word in cookedWords) {
        if (desc.contains(word) && !queryWords.contains(word)) score += 5;
      }

      // Penalize results missing all non-cooking base food words from the query.
      // e.g. for "steamed broccoli", any result without "broccoli" gets -20.
      final baseFoodWords = queryWords
          .where((w) => w.length > 3 && !cookedWords.contains(w))
          .toList();
      if (baseFoodWords.isNotEmpty &&
          !baseFoodWords.any((w) => desc.contains(w))) {
        score -= 20;
      }

      // Penalize ALL-CAPS brand names (USDA branded format: "MCDONALD'S, ...")
      final firstWord = desc.split(',').first.trim();
      if (firstWord == firstWord.toUpperCase() && firstWord.length > 2) {
        score -= 12;
      }

      debugPrint('USDA candidate: "$desc" score=$score');

      if (score > bestScore) {
        bestScore = score;
        bestFood = food;
      }
    }

    return bestFood as Map<String, dynamic>;
  }

  Future<List<String>> _getIngredients(int imageId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/nutrition/recipe/ingredients'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
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
    debugPrint('LogMeal API Error [$statusCode]: $body');
    String message = 'API Error ($statusCode)';
    try {
      final errorJson = jsonDecode(body);
      message = errorJson['message'] ?? errorJson['detail'] ?? message;
    } catch (_) {}
    return _errorResult('Scan Failed ($statusCode)', message);
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
