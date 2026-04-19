import 'package:best_flutter_ui_templates/fitness_app/models/tabIcon_data.dart';
import 'package:best_flutter_ui_templates/fitness_app/training/training_screen.dart';
import 'package:best_flutter_ui_templates/fitness_app/ui_view/account_screen.dart';
import 'package:best_flutter_ui_templates/fitness_app/my_diary/camera_screen.dart';
import 'package:best_flutter_ui_templates/fitness_app/my_diary/meals_list_view.dart';
import 'package:best_flutter_ui_templates/fitness_app/providers/app_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/my_diary/calendar_screen.dart';
import 'package:best_flutter_ui_templates/fitness_app/training/workout_timer_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bottom_navigation_view/bottom_bar_view.dart';
import 'fitness_app_theme.dart';
import 'my_diary/my_diary_screen.dart';

class FitnessAppHomeScreen extends StatefulWidget {
  @override
  _FitnessAppHomeScreenState createState() => _FitnessAppHomeScreenState();
}

class _FitnessAppHomeScreenState extends State<FitnessAppHomeScreen>
    with TickerProviderStateMixin {
  AnimationController? animationController;
  List<TabIconData> tabIconsList = TabIconData.tabIconsList;
  bool _hasCheckedBmi = false;

  Widget tabBody = Container(
    color: FitnessAppTheme.background,
  );

  @override
  void initState() {
    tabIconsList.forEach((TabIconData tab) {
      tab.isSelected = false;
    });
    tabIconsList[0].isSelected = true;

    animationController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    tabBody = MyDiaryScreen(animationController: animationController);
    
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.addListener(_onProviderUpdate);
      _checkBmiRequirement();
    });
  }

  void _onProviderUpdate() {
    if (!mounted || _hasCheckedBmi) return;
    _checkBmiRequirement();
  }

  void _checkBmiRequirement() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.isInitialLoadComplete && !_hasCheckedBmi) {
      if (appProvider.isBmiUpdateRequired) {
        _hasCheckedBmi = true;
        _showBmiUpdateDialog();
      } else if (appProvider.weight > 0) {
        _hasCheckedBmi = true;
      }
    }
  }

  void _showBmiUpdateDialog() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final weightController = TextEditingController(text: appProvider.weight > 0 ? appProvider.weight.toString() : '');
    final heightController = TextEditingController(text: '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.monitor_weight, color: FitnessAppTheme.nearlyDarkBlue),
              SizedBox(width: 12),
              Text('Weekly BMI Update', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please update your weight. Height is optional.',
                style: TextStyle(color: FitnessAppTheme.grey),
              ),
              const SizedBox(height: 12),
              if (appProvider.height > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.height, color: FitnessAppTheme.nearlyDarkBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Previous Height: ${appProvider.height.toInt()} cm',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FitnessAppTheme.nearlyDarkBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Current Weight (kg)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.fitness_center),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Height (cm) - Optional',
                  hintText: 'Leave blank to keep current',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.height),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text);
                final height = double.tryParse(heightController.text);
                
                if (weight != null && weight > 0) {
                  try {
                    await Provider.of<AppProvider>(context, listen: false).logBmiUpdate(
                      weight,
                      height: height,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('BMI log saved successfully!')),
                    );
                  } catch (e) {
                    if (e.toString().contains('JWT expired')) {
                      await Supabase.instance.client.auth.signOut();
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error saving update. Please try again.')),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid weight.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FitnessAppTheme.nearlyDarkBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Save Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    animationController?.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: FitnessAppTheme.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32.0),
            topRight: Radius.circular(32.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FitnessAppTheme.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: FitnessAppTheme.nearlyDarkBlue),
              ),
              title: const Text('AI Camera Scan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Detect food and calories using AI'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                );
              },
            ),
            const Divider(indent: 70),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.green),
              ),
              title: const Text('Manual Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Type in your meal details manually'),
              onTap: () {
                Navigator.pop(context);
                _showManualAddDialog();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showManualAddDialog() {
    final nameController = TextEditingController();
    final calController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Meal Manually', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Meal Name (e.g., Apple)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.fastfood),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: calController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Calories (kcal)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_fire_department),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein (g)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs (g)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fat (g)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && calController.text.isNotEmpty) {
                final appProvider = Provider.of<AppProvider>(context, listen: false);
                await appProvider.addFoodItem(
                  nameController.text,
                  double.tryParse(calController.text) ?? 0,
                  protein: double.tryParse(proteinController.text) ?? 0,
                  carbs: double.tryParse(carbsController.text) ?? 0,
                  fat: double.tryParse(fatController.text) ?? 0,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meal added successfully!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FitnessAppTheme.nearlyDarkBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add Meal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActiveTimerDialog() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.activeWorkoutName == null && appProvider.timerSeconds == 0) return;

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
                        animation: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                            parent: animationController!,
                            curve: Curves.fastOutSlowIn)),
                        workoutName: appProvider.activeWorkoutName,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FitnessAppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<bool>(
          future: getData(),
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox();
            } else {
              return Stack(
                children: <Widget>[
                  tabBody,
                  _buildMinimizedTimer(),
                  bottomBar(),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildMinimizedTimer() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        if (appProvider.timerSeconds == 0) return const SizedBox();
        
        return Positioned(
          bottom: 100, // Above the bottom bar
          right: 24,
          child: GestureDetector(
            onTap: () {
              _showActiveTimerDialog();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: FitnessAppTheme.nearlyDarkBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: FitnessAppTheme.nearlyDarkBlue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    appProvider.isTimerRunning ? Icons.timer : Icons.pause_circle_filled,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(appProvider.timerSeconds ~/ 60).toString().padLeft(2, '0')}:${(appProvider.timerSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: FitnessAppTheme.fontName,
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

  Future<bool> getData() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  Widget bottomBar() {
    return Column(
      children: <Widget>[
        const Expanded(
          child: SizedBox(),
        ),
        BottomBarView(
          tabIconsList: tabIconsList,
          addClick: () {
            _showAddDialog();
          },
          changeIndex: (int index) {
            if (index == 0) {
              animationController?.reverse().then<dynamic>((data) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  tabBody =
                      MyDiaryScreen(animationController: animationController);
                });
              });
            } else if (index == 1) {
              animationController?.reverse().then<dynamic>((data) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  tabBody =
                      TrainingScreen(animationController: animationController);
                });
              });
            } else if (index == 2) {
              animationController?.reverse().then<dynamic>((data) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  tabBody = CalendarScreen(animationController: animationController);
                });
              });
            } else if (index == 3) {
                animationController?.reverse().then<dynamic>((data) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  tabBody =
                      AccountScreen(animationController: animationController);
                });
              });
            }
          },
        ),
      ],
    );
  }
}
