import 'dart:io';
import 'package:camera/camera.dart';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
                    decoration: const InputDecoration(
                      labelText: 'Food Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fastfood),
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

                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    'Is this food wrong?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text(
                    'Pick a better match:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // Alternatives List
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.allMatches
                        .map(
                          (match) => ChoiceChip(
                            label: Text(match.name),
                            selected: nameController.text == match.name,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  nameController.text = match.name;
                                });
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final double finalCals =
                    double.tryParse(calController.text) ?? 0;
                Provider.of<AppProvider>(context, listen: false).addFoodItem(
                  nameController.text,
                  finalCals,
                  protein: result.protein,
                  carbs: result.carbs,
                  fat: result.fat,
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
