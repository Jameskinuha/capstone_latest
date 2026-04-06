import 'dart:async';
import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';

class WorkoutTimerView extends StatefulWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;

  const WorkoutTimerView({Key? key, this.animationController, this.animation})
      : super(key: key);

  @override
  _WorkoutTimerViewState createState() => _WorkoutTimerViewState();
}

class _WorkoutTimerViewState extends State<WorkoutTimerView> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _seconds = 0;
    });
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: widget.animation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - widget.animation!.value), 0.0),
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Workout Timer',
                        style: TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: FitnessAppTheme.darkerText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatTime(_seconds),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: FitnessAppTheme.nearlyDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isRunning ? _stopTimer : _startTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning ? Colors.red : Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text(_isRunning ? 'Stop' : 'Start'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _resetTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FitnessAppTheme.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      if (_seconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Estimated calories burned: ${(_seconds * 0.15).toStringAsFixed(1)} kcal',
                            style: const TextStyle(
                              fontSize: 14,
                              color: FitnessAppTheme.grey,
                            ),
                          ),
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
