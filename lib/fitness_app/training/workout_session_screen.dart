import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/training/workout_timer_view.dart';
import 'package:flutter/material.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final Map<String, dynamic> workoutData;

  const WorkoutSessionScreen({Key? key, required this.workoutData}) : super(key: key);

  @override
  _WorkoutSessionScreenState createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> with TickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> animation;

  @override
  void initState() {
    animationController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: animationController,
        curve: Curves.fastOutSlowIn));
    animationController.forward();
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitnessAppTheme.background,
      appBar: AppBar(
        title: Text(widget.workoutData['name'] ?? 'Workout Session',
            style: const TextStyle(color: FitnessAppTheme.darkerText, fontWeight: FontWeight.bold)),
        backgroundColor: FitnessAppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: FitnessAppTheme.nearlyBlack),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: FitnessAppTheme.white,
              child: TabBar(
                indicatorColor: FitnessAppTheme.nearlyDarkBlue,
                labelColor: FitnessAppTheme.nearlyDarkBlue,
                unselectedLabelColor: FitnessAppTheme.grey,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
                  Tab(text: 'Timer', icon: Icon(Icons.timer_outlined)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(),
                  WorkoutTimerView(
                    animationController: animationController,
                    animation: animation,
                    workoutName: widget.workoutData['name'],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Hero(
                tag: widget.workoutData['name'] ?? 'workout_hero',
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Image.asset(widget.workoutData['image'] ?? 'assets/fitness_app/runner.png'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.workoutData['name'] ?? '',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FitnessAppTheme.darkerText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.workoutData['desc'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                color: FitnessAppTheme.grey,
              ),
            ),
            const SizedBox(height: 32),
            _buildStatRow(Icons.bolt, 'Intensity (MET)', '${widget.workoutData['met']}'),
            const SizedBox(height: 16),
            _buildStatRow(Icons.local_fire_department, 'Target', 'Burn off daily intake'),
            const SizedBox(height: 48),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  FitnessAppTheme.nearlyDarkBlue,
                  FitnessAppTheme.nearlyDarkBlue.withOpacity(0.6),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Text(
                    'Ready to start?',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Switch to the Timer tab to begin your session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: FitnessAppTheme.nearlyDarkBlue),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 16, color: FitnessAppTheme.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FitnessAppTheme.darkerText)),
      ],
    );
  }
}
