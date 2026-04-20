import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/food_detection_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _imagePath;
  final FoodDetectionService _detectionService = FoodDetectionService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );

      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('Camera initialization error: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();

      setState(() {
        _imagePath = image.path;
        _isProcessing = true;
      });

      final File processedFile = await _processImage(File(image.path));
      final result = await _detectionService.detectFood(processedFile.path);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _imagePath = processedFile.path;
        });
        if (result != null) {
          _showInteractionDialog(result, processedFile.path);
        } else {
          _showError('AI could not identify the food. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error capturing image: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null) return;

      setState(() {
        _imagePath = picked.path;
        _isProcessing = true;
      });

      final File processedFile = await _processImage(File(picked.path));
      final result = await _detectionService.detectFood(processedFile.path);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _imagePath = processedFile.path;
        });
        if (result != null) {
          _showInteractionDialog(result, processedFile.path);
        } else {
          _showError('AI could not identify the food. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error picking image: $e');
      }
    }
  }

  Future<File> _processImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? capturedImage = img.decodeImage(bytes);
    if (capturedImage == null) return imageFile;

    img.Image resized;
    if (capturedImage.width < capturedImage.height) {
      resized = img.copyResize(capturedImage, width: 1024);
    } else {
      resized = img.copyResize(capturedImage, height: 1024);
    }

    final directory = await getTemporaryDirectory();
    final String path =
        '${directory.path}/food_api_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File resultFile = File(path)
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 95));
    return resultFile;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showInteractionDialog(FoodDetectionResult result, String imagePath) {
    final nameController = TextEditingController(text: result.label);
    final calController = TextEditingController(
      text: result.estimatedCalories.toInt().toString(),
    );

    // Mutable macros that update on portion change or food re-fetch
    double currentProtein = result.protein;
    double currentCarbs = result.carbs;
    double currentFat = result.fat;

    // Base values (1x) for portion scaling
    double baseCalories = result.estimatedCalories;
    double baseProtein = result.protein;
    double baseCarbs = result.carbs;
    double baseFat = result.fat;

    // Portion multiplier
    double portionMultiplier = 1.0;
    bool isRefetching = false;

    // Drink volume input — re-evaluated whenever the food name changes
    bool isDrink = _isDrink(result.label);
    Timer? _nameDebounce;
    double baseServingMl = result.servingGrams;
    final volumeController = TextEditingController(
      text: result.servingGrams.round().toString(),
    );
    String volumeUnit = 'mL';

    void _applyPortion(StateSetter setState, double multiplier) {
      portionMultiplier = multiplier;
      final cal = (baseCalories * multiplier).round();
      calController.text = cal.toString();
      currentProtein = baseProtein * multiplier;
      currentCarbs = baseCarbs * multiplier;
      currentFat = baseFat * multiplier;
      setState(() {});
    }

    void _applyVolume(StateSetter setState) {
      final raw = double.tryParse(volumeController.text) ?? 0;
      final volumeMl = volumeUnit == 'L' ? raw * 1000 : raw;
      if (volumeMl <= 0 || baseServingMl <= 0) return;
      final ratio = volumeMl / baseServingMl;
      calController.text = (baseCalories * ratio).round().toString();
      currentProtein = baseProtein * ratio;
      currentCarbs = baseCarbs * ratio;
      currentFat = baseFat * ratio;
      setState(() {});
    }

    Future<void> _refetchNutrition(
      StateSetter setState,
      String foodName,
    ) async {
      setState(() => isRefetching = true);
      try {
        final data = await _detectionService
            .getNutritionFromDatabase(foodName)
            .timeout(const Duration(seconds: 6), onTimeout: () => {});
        if (data.isNotEmpty) {
          final branded = (data['suggestedServing'] ?? 0) > 0;
          if (branded) {
            baseCalories = data['calories'] ?? 0;
            baseProtein = data['protein'] ?? 0;
            baseCarbs = data['carbs'] ?? 0;
            baseFat = data['fat'] ?? 0;
            baseServingMl = data['suggestedServing'] ?? baseServingMl;
          } else {
            final servingG = FoodDetectionService.getServingGrams(foodName);
            final scale = servingG / 100.0;
            baseCalories = (data['calories'] ?? 0) * scale;
            baseProtein = (data['protein'] ?? 0) * scale;
            baseCarbs = (data['carbs'] ?? 0) * scale;
            baseFat = (data['fat'] ?? 0) * scale;
            baseServingMl = servingG;
          }
          // Re-apply current portion or volume
          if (isDrink) {
            _applyVolume(setState);
          } else {
            calController.text = (baseCalories * portionMultiplier)
                .round()
                .toString();
            currentProtein = baseProtein * portionMultiplier;
            currentCarbs = baseCarbs * portionMultiplier;
            currentFat = baseFat * portionMultiplier;
          }
        }
      } catch (e) {
        debugPrint('Re-fetch nutrition error: $e');
      }
      setState(() => isRefetching = false);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Review & Correct AI',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Edit Name
                  TextField(
                    controller: nameController,
                    onChanged: (val) {
                      setState(() => isDrink = _isDrink(val));
                      _nameDebounce?.cancel();
                      final trimmed = val.trim();
                      if (trimmed.isNotEmpty) {
                        _nameDebounce = Timer(
                          const Duration(milliseconds: 700),
                          () {
                            portionMultiplier = 1.0;
                            isDrink = _isDrink(trimmed);
                            _refetchNutrition(setState, trimmed);
                          },
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Food Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fastfood),
                      helperText: 'Type to search & update nutrition live',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Edit Calories
                  TextField(
                    controller: calController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calories (kcal)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_fire_department),
                      helperText: 'Tap to correct if too big or small',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Macro display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroChip('Protein', currentProtein, Colors.redAccent),
                      _macroChip('Carbs', currentCarbs, Colors.orangeAccent),
                      _macroChip('Fat', currentFat, Colors.blueAccent),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Portion / Volume selector
                  if (isDrink) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'How much did you drink?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: volumeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _applyVolume(setState),
                            decoration: InputDecoration(
                              labelText: 'Volume',
                              border: const OutlineInputBorder(),
                              suffixText: volumeUnit,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            final raw =
                                double.tryParse(volumeController.text) ?? 0;
                            if (volumeUnit == 'mL') {
                              volumeUnit = 'L';
                              volumeController.text = (raw / 1000)
                                  .toStringAsFixed(3)
                                  .replaceAll(RegExp(r'0+$'), '')
                                  .replaceAll(RegExp(r'\.$'), '0');
                            } else {
                              volumeUnit = 'mL';
                              volumeController.text = (raw * 1000)
                                  .round()
                                  .toString();
                            }
                            _applyVolume(setState);
                          },
                          child: Text(volumeUnit),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'How much did you eat?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _portionChip(
                            'Half',
                            '~${(baseCalories * 0.5).round()} kcal',
                            0.5,
                            portionMultiplier,
                            (v) => _applyPortion(setState, v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _portionChip(
                            '1 serving',
                            '~${baseCalories.round()} kcal',
                            1.0,
                            portionMultiplier,
                            (v) => _applyPortion(setState, v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _portionChip(
                            '1½ srv',
                            '~${(baseCalories * 1.5).round()} kcal',
                            1.5,
                            portionMultiplier,
                            (v) => _applyPortion(setState, v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _portionChip(
                            'Double',
                            '~${(baseCalories * 2.0).round()} kcal',
                            2.0,
                            portionMultiplier,
                            (v) => _applyPortion(setState, v),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),

                  if (isRefetching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Updating nutrition…',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  const Text(
                    'Is this food wrong?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text(
                    'Pick a better match:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // Alternatives List — re-fetches nutrition on pick
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.allMatches
                        .map(
                          (match) => ChoiceChip(
                            label: Text(match.name),
                            selected: nameController.text == match.name,
                            onSelected: isRefetching
                                ? null
                                : (selected) {
                                    if (selected &&
                                        nameController.text != match.name) {
                                      nameController.text = match.name;
                                      portionMultiplier = 1.0;
                                      isDrink = _isDrink(match.name);
                                      _refetchNutrition(setState, match.name);
                                    }
                                  },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameDebounce?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isRefetching
                  ? null
                  : () async {
                      _nameDebounce?.cancel();
                      final double finalCals =
                          double.tryParse(calController.text) ?? 0;

                      // Save correction to local cache if user changed the food name
                      if (nameController.text != result.label) {
                        await _saveFoodCorrection(
                          result.label,
                          nameController.text,
                        );
                      }

                      if (!context.mounted) return;
                      Provider.of<AppProvider>(
                        context,
                        listen: false,
                      ).addFoodItem(
                        nameController.text,
                        finalCals,
                        protein: currentProtein,
                        carbs: currentCarbs,
                        fat: currentFat,
                        exerciseSuggestions: "Corrected by user.",
                      );
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
              child: const Text(
                'Confirm & Add',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  bool _isDrink(String name) {
    final n = name.toLowerCase();
    const drinkWords = [
      'juice',
      'drink',
      'tea',
      'coffee',
      'soda',
      'cola',
      'water',
      'milk',
      'shake',
      'smoothie',
      'beer',
      'wine',
      'lemonade',
      'beverage',
      'coke',
      'sprite',
      'pepsi',
      'nestea',
      'milo',
      'gatorade',
      'yakult',
      'iced tea',
      'red bull',
      'energy drink',
    ];
    return drinkWords.any((w) => n.contains(w));
  }

  Widget _portionChip(
    String label,
    String kcalHint,
    double value,
    double current,
    ValueChanged<double> onTap,
  ) {
    final selected = (current - value).abs() < 0.01;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? FitnessAppTheme.nearlyDarkBlue
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              kcalHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves a food name correction so future scans can reuse it.
  Future<void> _saveFoodCorrection(
    String originalName,
    String correctedName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString('food_corrections') ?? '{}';
      final Map<String, dynamic> corrections = jsonDecode(raw);
      corrections[originalName.toLowerCase()] = correctedName;
      await prefs.setString('food_corrections', jsonEncode(corrections));
      debugPrint('Saved correction: "$originalName" → "$correctedName"');
    } catch (e) {
      debugPrint('Error saving correction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _isProcessing && _imagePath != null
                ? SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                  )
                : SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CameraPreview(_controller!),
                  ),
          ),
          if (!_isProcessing)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black38,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black38,
                  ],
                ),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (!_isProcessing)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery upload button
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  // Camera capture button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          height: 60,
                          width: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Spacer to balance layout
                  const SizedBox(width: 56, height: 56),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
