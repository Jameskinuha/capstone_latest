import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

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
  final double servingGrams;

  FoodDetectionResult({
    required this.label,
    required this.estimatedCalories,
    required this.exerciseSuggestions,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.ingredients = const [],
    this.allMatches = const [],
    this.servingGrams = 150.0,
  });
}

class FoodDetectionService {
  static const String _token = 'b025576392d37d0a97f9ae240e67b401436f802e';
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

      String foodName = matches[0].name;

      // Check local correction cache — if the user previously corrected this food,
      // use the corrected name for the nutrition lookup.
      final correctedName = await _getCorrectedFoodName(foodName);
      if (correctedName != null) {
        debugPrint('Using cached correction: "$foodName" → "$correctedName"');
        foodName = correctedName;
      }

      // Fetch nutrition from USDA/FNRI + ingredients from LogMeal in parallel
      final results = await Future.wait([
        getNutritionFromDatabase(foodName),
        _getIngredients(imageId),
      ]);

      final nutritionData = results[0] as Map<String, double>;
      final ingredientsList = results[1] as List<String>;

      double calories;
      double protein;
      double carbs;
      double fat;
      double resultServingGrams = getServingGrams(foodName);

      if (nutritionData.isNotEmpty) {
        // If a branded serving size was resolved, values are already per-serving.
        // Otherwise scale from per-100g using food-type serving estimate.
        final branded = (nutritionData['suggestedServing'] ?? 0) > 0;
        if (branded) {
          calories = nutritionData['calories'] ?? 0;
          protein = nutritionData['protein'] ?? 0;
          carbs = nutritionData['carbs'] ?? 0;
          fat = nutritionData['fat'] ?? 0;
          resultServingGrams =
              nutritionData['suggestedServing'] ?? resultServingGrams;
          debugPrint(
            'Nutrition source: USDA Branded — $foodName '
            '(label serving): ${calories.toStringAsFixed(1)} kcal',
          );
        } else {
          final servingG = getServingGrams(foodName);
          final scale = servingG / 100.0;
          calories = (nutritionData['calories'] ?? 0) * scale;
          protein = (nutritionData['protein'] ?? 0) * scale;
          carbs = (nutritionData['carbs'] ?? 0) * scale;
          fat = (nutritionData['fat'] ?? 0) * scale;
          debugPrint(
            'Nutrition source: USDA/FNRI — $foodName '
            '(${servingG.toStringAsFixed(0)}g serving): '
            '${calories.toStringAsFixed(1)} kcal',
          );
        }
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
        servingGrams: resultServingGrams,
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
  /// Checks local FNRI Filipino food table first, then USDA generic,
  /// then USDA Branded as a fallback for packaged/branded foods.
  /// Public so the review dialog can re-fetch when the user picks an alternative.
  Future<Map<String, double>> getNutritionFromDatabase(String foodName) async {
    // 0. Zero-calorie items — skip all API calls
    if (_isZeroCalorie(foodName)) {
      debugPrint('Zero-calorie shortcut for "$foodName"');
      return {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
    }

    // 1. Check Filipino food database first (FNRI data)
    final filipinoResult = _lookupFilipinoFood(foodName);
    if (filipinoResult.isNotEmpty) {
      debugPrint(
        'FNRI match for "$foodName": ${filipinoResult['calories']} kcal',
      );
      return filipinoResult;
    }

    // 2. USDA SR Legacy / Foundation (generic whole foods, per 100g)
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
          final (food, score) = _pickBestMatch(foodName, foods);

          // Only use this result if it's a plausible match (score >= 5)
          if (score >= 5) {
            final List nutrients = food['foodNutrients'] ?? [];
            double calories = 0, protein = 0, carbs = 0, fat = 0;
            for (final n in nutrients) {
              final name = (n['nutrientName'] ?? '').toString().toLowerCase();
              final unit = (n['unitName'] ?? '').toString().toUpperCase();
              final value = _toDouble(n['value']);
              if (name == 'energy' && unit == 'KCAL')
                calories = value;
              else if (name == 'protein')
                protein = value;
              else if (name.contains('carbohydrate'))
                carbs = value;
              else if (name == 'total lipid (fat)')
                fat = value;
            }
            debugPrint(
              'USDA SR match (score=$score): "${food['description']}" → ${calories}kcal',
            );
            return {
              'calories': calories,
              'protein': protein,
              'carbs': carbs,
              'fat': fat,
            };
          } else {
            debugPrint(
              'USDA SR poor match (score=$score): "${food['description']}" — trying branded',
            );
          }
        }
      } else {
        debugPrint('USDA API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('USDA SR Error: $e');
    }

    // 3. USDA Branded fallback — for packaged/junk foods where SR has no match.
    //    Returns already-scaled per-serving values (label calories) via suggestedServing > 0.
    return await _queryBrandedUSDA(foodName);
  }

  /// Queries USDA Branded Foods database and returns label-accurate per-serving nutrition.
  /// Sets suggestedServing > 0 so detectFood() skips the generic serving-size estimate.
  Future<Map<String, double>> _queryBrandedUSDA(String foodName) async {
    try {
      final url = Uri.parse(
        '$_nutritionApiUrl?query=${Uri.encodeComponent(foodName)}&pageSize=10&dataType=Branded&api_key=$_usdaApiKey',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return {};

      final data = jsonDecode(response.body);
      final List foods = data['foods'] ?? [];
      if (foods.isEmpty) return {};

      // Simple scoring for branded: reward query word matches, skip ALL-CAPS penalty
      final queryWords = foodName.toLowerCase().split(' ');
      int bestScore = -999;
      dynamic bestFood = foods[0];
      for (final food in foods) {
        final desc = (food['description'] ?? '').toString().toLowerCase();

        // Skip entries with no calorie data
        final double kcal = _extractKcal(food);
        if (kcal == 0) continue;

        int score = 0;
        for (final w in queryWords) {
          if (desc.contains(w)) score += 10;
        }
        // Penalize clearly wrong categories
        const wrongTypes = [
          'cake',
          'sauce',
          'candy',
          'chew',
          'gum',
          'syrup',
          'extract',
          'mix',
          'diet',
          'zero',
          'light',
        ];
        for (final w in wrongTypes) {
          if (desc.contains(w) && !foodName.toLowerCase().contains(w))
            score -= 15;
        }
        // Penalize ALL-CAPS brand entries (first comma-segment is all uppercase)
        final firstSeg = (food['description'] ?? '')
            .toString()
            .split(',')[0]
            .trim();
        if (firstSeg == firstSeg.toUpperCase() && firstSeg.length > 2) {
          score -= 12;
        }
        // Prefer standard beverage can/cup sizes (300–473 mL) over bottles
        final double rawSrv = _toDouble(food['servingSize']);
        final String rawUnit = ((food['servingSizeUnit'] ?? '') as String)
            .toUpperCase();
        if ((rawUnit == 'ML' || rawUnit == 'MLT' || rawUnit == 'MLL') &&
            rawSrv >= 300 &&
            rawSrv <= 473) {
          score += 5;
        }
        if (score > bestScore) {
          bestScore = score;
          bestFood = food;
        }
      }

      final List nutrients = bestFood['foodNutrients'] ?? [];
      double calories = 0, protein = 0, carbs = 0, fat = 0;
      for (final n in nutrients) {
        final name = (n['nutrientName'] ?? '').toString().toLowerCase();
        final unit = (n['unitName'] ?? '').toString().toUpperCase();
        final value = _toDouble(n['value']);
        if (name == 'energy' && unit == 'KCAL')
          calories = value;
        else if (name == 'protein')
          protein = value;
        else if (name.contains('carbohydrate'))
          carbs = value;
        else if (name == 'total lipid (fat)')
          fat = value;
      }

      // Apply the label serving size if available and valid
      final double rawServing = _toDouble(bestFood['servingSize']);
      final String servUnit = ((bestFood['servingSizeUnit'] ?? '') as String)
          .toUpperCase();
      // Accept gram-based and mL-based units; skip nonsensical micro-units
      final bool validServing =
          rawServing > 1 &&
          (servUnit == 'G' ||
              servUnit == 'GRM' ||
              servUnit == 'ML' ||
              servUnit == 'MLT' ||
              servUnit == 'MLL' ||
              servUnit.isEmpty);

      if (validServing) {
        final scale = rawServing / 100.0;
        debugPrint(
          'USDA Branded match: "${bestFood['description']}" '
          '(${rawServing}${servUnit} serving) → ${(calories * scale).toStringAsFixed(1)} kcal',
        );
        return {
          'calories': calories * scale,
          'protein': protein * scale,
          'carbs': carbs * scale,
          'fat': fat * scale,
          'suggestedServing':
              rawServing, // signals detectFood() not to re-scale
        };
      }

      // No valid serving size — return per-100g and let detectFood() scale
      debugPrint(
        'USDA Branded (no serving): "${bestFood['description']}" → ${calories}kcal/100g',
      );
      return {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
    } catch (e) {
      debugPrint('USDA Branded Error: $e');
      return {};
    }
  }

  /// Returns true for items that are inherently zero (or near-zero) calorie.
  static bool _isZeroCalorie(String foodName) {
    final n = foodName.toLowerCase();
    const zeroCalItems = [
      'water',
      'sparkling water',
      'mineral water',
      'soda water',
      'club soda',
      'plain water',
      'distilled water',
      'black coffee',
      'plain tea',
      'green tea',
      'herbal tea',
      'diet coke',
      'diet pepsi',
      'coke zero',
      'pepsi zero',
    ];
    // Exact or near-exact match only — avoid matching "coconut water", "tonic water"
    for (final item in zeroCalItems) {
      if (n == item || n == 'bottled $item' || n == '$item bottle') return true;
    }
    // Bare single-word "water" with no qualifiers
    if (n.trim() == 'water') return true;
    return false;
  }

  /// Returns the standard single-serving weight (grams) for a food name.
  /// USDA and FNRI data are per 100 g, so we scale by servingG / 100.
  static double getServingGrams(String foodName) {
    final name = foodName.toLowerCase();

    // Liquid-based dishes — a bowl is roughly 240 g
    if (name.contains('sinigang') ||
        name.contains('bulalo') ||
        name.contains('nilaga') ||
        name.contains('tinola') ||
        name.contains('soup') ||
        name.contains('mami') ||
        name.contains('batchoy') ||
        name.contains('lugaw'))
      return 240.0;

    // Rice and grain dishes — 1 cup cooked ≈ 186 g
    if (name.contains('rice') ||
        name.contains('sinangag') ||
        name.contains('arroz') ||
        name.contains('champorado'))
      return 186.0;

    // Noodle dishes — 1 cup ≈ 150 g
    if (name.contains('pancit') ||
        name.contains('palabok') ||
        name.contains('noodle') ||
        name.contains('pasta'))
      return 150.0;

    // Eggs — 1 large egg ≈ 50 g
    if (name.contains('egg')) return 50.0;

    // Snacks, chips, and dense foods — 1 oz ≈ 28 g
    if (name.contains('chip') ||
        name.contains('crisp') ||
        name.contains('cracker') ||
        name.contains('cookie') ||
        name.contains('biscuit') ||
        name.contains('nut') ||
        name.contains('chocolate') ||
        name.contains('candy') ||
        name.contains('pretzel') ||
        name.contains('popcorn'))
      return 28.0;

    // Breads and pastries — 1 slice / medium piece ≈ 35-50 g
    if (name.contains('bread') ||
        name.contains('toast') ||
        name.contains('pandesal') ||
        name.contains('bun') ||
        name.contains('roll') ||
        name.contains('croissant'))
      return 50.0;

    // Meats and fish (if not already handled by a dish name) — ~3 oz ≈ 85 g
    if (name.contains('meat') ||
        name.contains('pork') ||
        name.contains('beef') ||
        name.contains('chicken') ||
        name.contains('fish') ||
        name.contains('steak') ||
        name.contains('sausage'))
      return 85.0;

    // Fruits — 1 medium piece ≈ 114 g
    if (name.contains('fruit') ||
        name.contains('apple') ||
        name.contains('banana') ||
        name.contains('orange') ||
        name.contains('mango'))
      return 114.0;

    // Default: 150 g — a typical single-food serving
    return 150.0;
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
  /// Returns (bestFood, bestScore) so callers can gauge match quality.
  (Map<String, dynamic>, int) _pickBestMatch(String query, List foods) {
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
      'oil',
      'extract',
      'croissant',
      'pastry',
      'cake',
      'strudel',
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

      // Skip entries with no calorie data — they skew scoring
      final double kcal = _extractKcal(food);
      if (kcal == 0) continue;

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

    return (bestFood as Map<String, dynamic>, bestScore);
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

  /// Extracts KCAL energy value from a USDA food entry. Returns 0 if absent.
  static double _extractKcal(dynamic food) {
    final List nutrients = food['foodNutrients'] ?? [];
    for (final n in nutrients) {
      final name = (n['nutrientName'] ?? '').toString().toLowerCase();
      final unit = (n['unitName'] ?? '').toString().toUpperCase();
      if (name == 'energy' && unit == 'KCAL')
        return _toDoubleStatic(n['value']);
    }
    return 0;
  }

  static double _toDoubleStatic(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Returns the user-corrected food name from local cache, or null.
  Future<String?> _getCorrectedFoodName(String originalName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString('food_corrections') ?? '{}';
      final Map<String, dynamic> corrections = jsonDecode(raw);
      final corrected = corrections[originalName.toLowerCase()];
      return corrected is String ? corrected : null;
    } catch (e) {
      debugPrint('Error reading correction cache: $e');
      return null;
    }
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
