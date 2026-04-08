import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/providers/app_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/training/workout_timer_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutsListView extends StatelessWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;

  const WorkoutsListView({Key? key, this.animationController, this.animation})
      : super(key: key);

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
        final double calories = appProvider.totalCalories;
        final double weight = appProvider.weight > 0 ? appProvider.weight : 70.0;

        // Formula: Minutes = Calories / ((MET * 3.5 * weight) / 200)
        double calPerMin(double met) => (met * 3.5 * weight) / 200;

        final workouts = [
          {
            'name': 'Walking (Brisk)',
            'desc': 'Walking at a steady, brisk pace',
            'met': 3.5,
            'image': 'assets/fitness_app/back.png'
          },
          {
            'name': 'Running (Slow)',
            'desc': 'Jogging at around 8km/h',
            'met': 10.0,
            'image': 'assets/fitness_app/runner.png'
          },
          {
            'name': 'Cycling (Moderate)',
            'desc': 'Cycling at a moderate speed',
            'met': 8.0,
            'image': 'assets/fitness_app/back.png'
          },
          {
            'name': 'Push-ups/Sit-ups',
            'desc': 'Vigorous calisthenics',
            'met': 8.0,
            'image': 'assets/fitness_app/back.png'
          },
          {
            'name': 'Swimming (Laps)',
            'desc': 'Swimming laps at a moderate pace',
            'met': 7.0,
            'image': 'assets/fitness_app/back.png'
          },
        ];

        return FadeTransition(
          opacity: animation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - animation!.value), 0.0),
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended Workouts',
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: FitnessAppTheme.darkerText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To burn off your current intake (${calories.toInt()} kcal)',
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontSize: 12,
                                  color: FitnessAppTheme.grey.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: FitnessAppTheme.nearlyDarkBlue),
                            onPressed: appProvider.timerSeconds > 0 ? null : () => _showManualWorkoutDialog(context),
                          )
                        ],
                      ),
                    ),
                    ...workouts.map((workout) {
                      int mins = (calories / calPerMin(workout['met'] as double)).round();
                      
                      final bool isTimerActive = appProvider.timerSeconds > 0;
                      final bool isThisActive = appProvider.activeWorkoutName == workout['name'];
                      final bool isDisabled = isTimerActive && !isThisActive;

                      return Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Column(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isDisabled ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('A workout is already in progress!')),
                                  );
                                } : () {
                                  _showTimerDialog(context, workout['name'] as String);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        child: Hero(
                                          tag: workout['name'] as String,
                                          child: Image.asset(workout['image'] as String),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              workout['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: FitnessAppTheme.darkerText,
                                              ),
                                            ),
                                            Text(
                                              workout['desc'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: FitnessAppTheme.grey.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$mins min',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: FitnessAppTheme.nearlyDarkBlue,
                                            ),
                                          ),
                                          Text(
                                            'needed',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: FitnessAppTheme.grey.withOpacity(0.5),
                                              fontFamily: FitnessAppTheme.fontName,
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (workout != workouts.last)
                              Padding(
                                padding: const EdgeInsets.only(left: 80, right: 24),
                                child: Divider(height: 1, color: FitnessAppTheme.grey.withOpacity(0.2)),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
