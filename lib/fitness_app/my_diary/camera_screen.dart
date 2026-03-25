import 'dart:io';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/food_detection_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final FoodDetectionService _detectionService = FoodDetectionService();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    // No longer automatically opening camera to allow choice
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90, // High quality for AI
      );

      if (image == null) return;

      setState(() {
        _imagePath = image.path;
        _isProcessing = true;
      });
      
      final result = await _detectionService.detectFood(image.path);
      
      if (mounted) {
        setState(() => _isProcessing = false);
        if (result != null) {
          _showResultDialog(result, image.path);
        } else {
          _showError('AI could not identify the food. Please ensure the image is clear and centered.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: ${e.toString()}');
      }
    }
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
              Navigator.pop(context); // Close dialog
              setState(() {
                _imagePath = null;
                _isProcessing = false;
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
    return Scaffold(
      backgroundColor: FitnessAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('AI Food Analysis', style: TextStyle(color: Colors.black)),
      ),
      body: Center(
        child: _isProcessing 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_imagePath != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: FitnessAppTheme.nearlyDarkBlue),
                const SizedBox(height: 24),
                const Text('AI is analyzing your photo...', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Extracting nutritional data', 
                  style: TextStyle(color: Colors.grey)),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fastfood_outlined, size: 80, color: FitnessAppTheme.nearlyDarkBlue),
                const SizedBox(height: 24),
                const Text('How would you like to add food?', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _choiceCard(
                      icon: Icons.camera_alt,
                      label: 'Take Photo',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 24),
                    _choiceCard(
                      icon: Icons.photo_library,
                      label: 'Upload Photo',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );
  }

  Widget _choiceCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: FitnessAppTheme.nearlyDarkBlue),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
