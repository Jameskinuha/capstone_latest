import 'dart:io';
import 'package:camera/camera.dart';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
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
        ResolutionPreset.high, // Higher resolution for better AI detection
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
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      
      setState(() {
        _imagePath = image.path;
        _isProcessing = true;
      });

      // Crop the image to the center area defined by the border guide
      final File croppedFile = await _cropImage(File(image.path));
      
      final result = await _detectionService.detectFood(croppedFile.path);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _imagePath = croppedFile.path;
        });
        if (result != null) {
          _showResultDialog(result, croppedFile.path);
        } else {
          _showError('AI could not identify the food. Please ensure the food fills the box.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error capturing image: $e');
      }
    }
  }

  Future<File> _cropImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? capturedImage = img.decodeImage(bytes);

    if (capturedImage == null) return imageFile;

    // LogMeal prefers square images. We crop to the center.
    int size = capturedImage.width < capturedImage.height 
        ? capturedImage.width 
        : capturedImage.height;
    
    // We target the 80% center area to match the UI guide
    int cropSize = (size * 0.8).toInt();
    int offsetX = (capturedImage.width - cropSize) ~/ 2;
    int offsetY = (capturedImage.height - cropSize) ~/ 2;

    img.Image cropped = img.copyCrop(
      capturedImage, 
      x: offsetX, 
      y: offsetY, 
      width: cropSize, 
      height: cropSize
    );

    // Resize to a standard size for LogMeal (1024x1024 is good)
    img.Image resized = img.copyResize(cropped, width: 1024, height: 1024);

    final directory = await getTemporaryDirectory();
    final String path = '${directory.path}/food_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File resultFile = File(path)..writeAsBytesSync(img.encodeJpg(resized, quality: 90));
    
    return resultFile;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showResultDialog(FoodDetectionResult result, String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('AI Analysis Complete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(imagePath), height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              Text(result.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              Text('${result.estimatedCalories.toInt()} kcal', 
                style: const TextStyle(color: FitnessAppTheme.nearlyDarkBlue, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _macroWidget('Protein', result.protein, Colors.redAccent),
                  _macroWidget('Carbs', result.carbs, Colors.orangeAccent),
                  _macroWidget('Fat', result.fat, Colors.yellow[700]!),
                ],
              ),
              const Divider(),
              const Text('Exercise Suggestions:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(result.exerciseSuggestions, textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _imagePath = null;
              });
            }, 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FitnessAppTheme.nearlyDarkBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Provider.of<AppProvider>(context, listen: false).addFoodItem(
                result.label, 
                result.estimatedCalories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                exerciseSuggestions: result.exerciseSuggestions,
              );
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Add to Diary'),
          ),
        ],
      ),
    );
  }

  Widget _macroWidget(String label, double value, Color color) {
    return Column(
      children: [
        Text(value.toStringAsFixed(1) + 'g', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
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
          // Camera Preview or Captured Image
          Center(
            child: _isProcessing && _imagePath != null
                ? SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                  )
                : AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
          ),

          // Border Guide (Only show if not processing)
          if (!_isProcessing)
            Center(
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

          // Dimmed Background outside border (Only show if not processing)
          if (!_isProcessing)
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: size.width * 0.8,
                      height: size.width * 0.8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Analyzing Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'AI is analyzing your photo...',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // Header
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                if (!_isProcessing)
                  const Text(
                    'Center food in box',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                const SizedBox(width: 48), // Spacer
              ],
            ),
          ),

          // Capture Button
          if (!_isProcessing)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
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
              ),
            ),
        ],
      ),
    );
  }
}
