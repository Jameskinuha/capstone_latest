import 'dart:async';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class WorkoutTimerView extends StatefulWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;
  final String? workoutName;

  const WorkoutTimerView({Key? key, this.animationController, this.animation, this.workoutName})
      : super(key: key);

  @override
  _WorkoutTimerViewState createState() => _WorkoutTimerViewState();
}

class _WorkoutTimerViewState extends State<WorkoutTimerView> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _pulseController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    super.initState();
    
    // Check initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.isTimerRunning) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  void _toggleTimer() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.isTimerRunning) {
      appProvider.pauseTimer();
      _pulseController.stop();
    } else {
      appProvider.startTimer(widget.workoutName ?? appProvider.activeWorkoutName ?? 'General Workout');
      _pulseController.repeat(reverse: true);
    }
  }

  void _stopAndSave() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.timerSeconds > 0) {
      final double caloriesBurned = appProvider.calculateBurnedCalories();
      final String name = appProvider.activeWorkoutName ?? widget.workoutName ?? 'General Workout';
      final int seconds = appProvider.timerSeconds;

      appProvider.addWorkoutItem(name, seconds, caloriesBurned);
      appProvider.resetTimer();
      _pulseController.stop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout saved: ${caloriesBurned.toStringAsFixed(1)} kcal'),
          backgroundColor: FitnessAppTheme.nearlyDarkBlue,
        ),
      );
    }
  }

  void _reset() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.resetTimer();
    _pulseController.stop();
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        // Sync pulse controller with running state
        if (appProvider.isTimerRunning && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!appProvider.isTimerRunning && _pulseController.isAnimating) {
          _pulseController.stop();
        }

        final int seconds = appProvider.timerSeconds;
        final bool isRunning = appProvider.isTimerRunning;
        final String displayName = widget.workoutName ?? appProvider.activeWorkoutName ?? 'Workout Session';

        return AnimatedBuilder(
          animation: widget.animationController!,
          builder: (BuildContext context, Widget? child) {
            return FadeTransition(
              opacity: widget.animation!,
              child: Transform(
                transform: Matrix4.translationValues(
                    0.0, 30 * (1.0 - widget.animation!.value), 0.0),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            color: FitnessAppTheme.darkerText,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 1.0, end: 1.1).animate(
                                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                              ),
                              child: Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.05),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: CustomPaint(
                                painter: TimerPainter(
                                  backgroundColor: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.1),
                                  color: FitnessAppTheme.nearlyDarkBlue,
                                  percent: (seconds % 60) / 60,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(seconds),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: FitnessAppTheme.nearlyDarkBlue,
                                    fontFamily: FitnessAppTheme.fontName,
                                  ),
                                ),
                                Text(
                                  isRunning ? 'ACTIVE' : (seconds > 0 ? 'PAUSED' : 'READY'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isRunning ? Colors.green : (seconds > 0 ? Colors.orange : FitnessAppTheme.grey),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                          decoration: BoxDecoration(
                            color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Kcal Burned',
                                appProvider.calculateBurnedCalories().toStringAsFixed(1),
                                Icons.local_fire_department,
                                Colors.orange,
                              ),
                              _buildStatItem(
                                'Duration',
                                '${(seconds / 60).floor()}m',
                                Icons.timer,
                                Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Play/Pause Button
                            _buildControlButton(
                              onTap: _toggleTimer,
                              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: isRunning ? Colors.orange : Colors.green,
                              isLarge: true,
                            ),
                            const SizedBox(width: 24),
                            // Stop/Save Button
                            _buildControlButton(
                              onTap: _stopAndSave,
                              icon: Icons.stop_rounded,
                              color: Colors.red,
                              isLarge: true,
                              enabled: seconds > 0,
                            ),
                            const SizedBox(width: 24),
                            // Reset Button
                            _buildControlButton(
                              onTap: _reset,
                              icon: Icons.refresh_rounded,
                              color: FitnessAppTheme.grey,
                              isLarge: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isRunning ? 'Tap PAUSE to take a break' : (seconds > 0 ? 'Tap PLAY to resume or STOP to save' : 'Tap PLAY to start tracking'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: FitnessAppTheme.grey.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: FitnessAppTheme.darkerText,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: FitnessAppTheme.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({required VoidCallback onTap, required IconData icon, required Color color, bool isLarge = false, bool enabled = true}) {
    double size = isLarge ? 74 : 64;
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: FitnessAppTheme.white,
            shape: BoxShape.circle,
            boxShadow: [
              if (enabled) BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.1), width: 2),
          ),
          child: Icon(icon, size: isLarge ? 40 : 32, color: color),
        ),
      ),
    );
  }
}

class TimerPainter extends CustomPainter {
  final Color backgroundColor;
  final Color color;
  final double percent;

  TimerPainter({required this.backgroundColor, required this.color, required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);

    paint.color = color;
    double progressAngle = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2),
      -math.pi / 2,
      progressAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(TimerPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}
