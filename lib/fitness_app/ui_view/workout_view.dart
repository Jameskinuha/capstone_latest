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

        final List<Map<String, dynamic>> recommendations = [
          {
            'title': 'Walking (Brisk)',
            'sub': 'Walking at a steady, brisk pace',
            'icon': Icons.directions_walk,
            'color': Colors.blue,
            'burnRate': 3.37, 
          },
          {
            'title': 'Running (Slow)',
            'sub': 'Jogging at around 8km/h',
            'icon': Icons.directions_run,
            'color': Colors.orange,
            'burnRate': 9.57,
          },
          {
            'title': 'Cycling (Moderate)',
            'sub': 'Cycling at a moderate speed',
            'icon': Icons.directions_bike,
            'color': Colors.cyan,
            'burnRate': 7.68,
          },
          {
            'title': 'Push-ups/Sit-ups',
            'sub': 'Vigorous calisthenics',
            'icon': Icons.fitness_center,
            'color': Colors.purple,
            'burnRate': 7.68,
          },
        ];

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
                                'To burn off your current intake ($totalKcal kcal)',
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
                        itemCount: recommendations.length,
                        separatorBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(left: 64, top: 8, bottom: 8),
                          child: Divider(color: FitnessAppTheme.grey.withOpacity(0.1)),
                        ),
                        itemBuilder: (context, index) {
                          final item = recommendations[index];
                          final int minNeeded = totalKcal > 0 
                              ? (totalKcal / item['burnRate']).ceil()
                              : 0;
                          
                          final bool isThisActive = appProvider.activeWorkoutName == item['title'];
                          final bool isDisabled = isTimerActive && !isThisActive;

                          return Opacity(
                            opacity: isDisabled ? 0.4 : 1.0,
                            child: InkWell(
                              onTap: isDisabled ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('A workout is already in progress!')),
                                );
                              } : () => _showTimerDialog(context, item['title']),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: (item['color'] as Color).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item['icon'] as IconData,
                                        color: item['color'] as Color,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] as String,
                                            style: const TextStyle(
                                              fontFamily: FitnessAppTheme.fontName,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: FitnessAppTheme.darkerText,
                                            ),
                                          ),
                                          Text(
                                            item['sub'] as String,
                                            style: TextStyle(
                                              fontFamily: FitnessAppTheme.fontName,
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
