import 'package:best_flutter_ui_templates/fitness_app/providers/app_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/training/workout_timer_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../fitness_app_theme.dart';

class WorkoutView extends StatelessWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;

  const WorkoutView({Key? key, this.animationController, this.animation})
      : super(key: key);

  List<Map<String, dynamic>> _getFallbackRecommendations() {
    return [
      {
        'name': 'Push-ups',
        'category': 'Home Workout',
        'calories_per_minute': 7.0,
        'difficulty': 'Beginner'
      },
      {
        'name': 'Jumping Jacks',
        'category': 'Home Workout',
        'calories_per_minute': 8.0,
        'difficulty': 'Beginner'
      },
      {
        'name': 'Bench Press',
        'category': 'Gym Workout',
        'calories_per_minute': 6.5,
        'difficulty': 'Intermediate'
      },
      {
        'name': 'Treadmill (Running)',
        'category': 'Gym Workout',
        'calories_per_minute': 11.0,
        'difficulty': 'Intermediate'
      },
      {
        'name': 'Burpees',
        'category': 'Home Workout',
        'calories_per_minute': 10.0,
        'difficulty': 'Advanced'
      },
    ];
  }

  void _showTimerDialog(BuildContext context, String workoutName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: FitnessAppTheme.white,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8.0),
                          bottomLeft: Radius.circular(8.0),
                          bottomRight: Radius.circular(8.0),
                          topRight: Radius.circular(68.0)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                            color: FitnessAppTheme.grey.withOpacity(0.4),
                            offset: const Offset(1.1, 1.1),
                            blurRadius: 10.0),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: WorkoutTimerView(
                        animationController: animationController,
                        animation: animation,
                        workoutName: workoutName,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: FitnessAppTheme.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showManualWorkoutDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Workout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'What are you doing?',
            hintText: 'e.g. Yoga, HIIT, Zumba',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _showTimerDialog(context, nameController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: FitnessAppTheme.nearlyDarkBlue),
            child: const Text('Start Timer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController!,
      builder: (BuildContext context, Widget? child) {
        final appProvider = Provider.of<AppProvider>(context);
        final int totalKcal = appProvider.totalCalories.toInt();
        final bool isTimerActive = appProvider.timerSeconds > 0;
        
        // Use database catalog if available, otherwise use fallback data for speed
        final List<Map<String, dynamic>> recommendations = appProvider.workoutCatalog.isNotEmpty 
            ? appProvider.workoutCatalog 
            : _getFallbackRecommendations();

        return FadeTransition(
          opacity: animation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - animation!.value), 0.0),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 16, bottom: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: FitnessAppTheme.white,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      bottomLeft: Radius.circular(8.0),
                      bottomRight: Radius.circular(8.0),
                      topRight: Radius.circular(68.0)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: FitnessAppTheme.grey.withOpacity(0.2),
                        offset: const Offset(1.1, 1.1),
                        blurRadius: 10.0),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended Workouts',
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: FitnessAppTheme.darkerText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To burn off your intake ($totalKcal kcal)',
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontSize: 14,
                                  color: FitnessAppTheme.grey.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: FitnessAppTheme.nearlyDarkBlue),
                            onPressed: isTimerActive ? null : () => _showManualWorkoutDialog(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recommendations.length > 5 ? 5 : recommendations.length,
                        separatorBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(left: 64, top: 8, bottom: 8),
                          child: Divider(color: FitnessAppTheme.grey.withOpacity(0.1)),
                        ),
                        itemBuilder: (context, index) {
                          final item = recommendations[index];
                          final String title = item['name'] ?? 'Unknown';
                          final String category = item['category'] ?? 'General';
                          final double burnPerMin = (item['calories_per_minute'] as num).toDouble();
                          final String difficulty = item['difficulty'] ?? 'Beginner';
                          
                          final int minNeeded = totalKcal > 0 
                              ? (totalKcal / burnPerMin).ceil()
                              : 0;
                          
                          final bool isHome = category.toLowerCase().contains('home');
                          final IconData icon = isHome ? Icons.home_rounded : Icons.fitness_center_rounded;
                          final Color themeColor = isHome ? Colors.green : Colors.blue;

                          final bool isThisActive = appProvider.activeWorkoutName == title;
                          final bool isDisabled = isTimerActive && !isThisActive;

                          return Opacity(
                            opacity: isDisabled ? 0.4 : 1.0,
                            child: InkWell(
                              onTap: isDisabled ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('A workout is already in progress!')),
                                );
                              } : () => _showTimerDialog(context, title),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: themeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(icon, color: themeColor, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontFamily: FitnessAppTheme.fontName,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: FitnessAppTheme.darkerText,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: themeColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  category.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: themeColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                difficulty,
                                                style: TextStyle(
                                                  fontFamily: FitnessAppTheme.fontName,
                                                  fontSize: 12,
                                                  color: FitnessAppTheme.grey.withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$minNeeded min',
                                          style: const TextStyle(
                                            fontFamily: FitnessAppTheme.fontName,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: FitnessAppTheme.nearlyDarkBlue,
                                          ),
                                        ),
                                        Text(
                                          'needed',
                                          style: TextStyle(
                                            fontFamily: FitnessAppTheme.fontName,
                                            fontSize: 12,
                                            color: FitnessAppTheme.grey.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
