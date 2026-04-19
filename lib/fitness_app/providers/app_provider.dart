import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_diary_item.dart';
import 'package:intl/intl.dart';

class AppProvider with ChangeNotifier {
  final List<FoodDiaryItem> _foodItems = [];
  final List<Map<String, dynamic>> _workoutItems = [];
  final List<Map<String, dynamic>> _workoutCatalog = [];
  final List<Map<String, dynamic>> _bmiHistory = [];
  bool _isLoading = false;
  bool _isInitialLoadComplete = false;
  
  // User Profile Data
  int _calorieGoal = 2500;
  double _weight = 0;
  double _height = 0;
  int _age = 0;
  String _displayName = '';
  String _email = '';
  DateTime? _lastBmiUpdate;
  String _bmiUpdateFrequency = 'weekly'; // Default

  DateTime _selectedDate = DateTime.now();

  // Global Timer State
  Timer? _globalTimer;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;
  String? _activeWorkoutName;

  List<FoodDiaryItem> get foodItems => _foodItems;
  List<Map<String, dynamic>> get workoutItems => _workoutItems;
  List<Map<String, dynamic>> get workoutCatalog => _workoutCatalog;
  List<Map<String, dynamic>> get bmiHistory => _bmiHistory;
  bool get isLoading => _isLoading;
  bool get isInitialLoadComplete => _isInitialLoadComplete;
  
  int get calorieGoal => _calorieGoal;
  double get weight => _weight;
  double get height => _height;
  int get age => _age;
  String get displayName => _displayName;
  String get email => _email;
  DateTime? get lastBmiUpdate => _lastBmiUpdate;
  String get bmiUpdateFrequency => _bmiUpdateFrequency;

  DateTime get selectedDate => _selectedDate;

  // Timer Getters
  int get timerSeconds => _timerSeconds;
  bool get isTimerRunning => _isTimerRunning;
  String? get activeWorkoutName => _activeWorkoutName;

  bool get isBmiUpdateRequired {
    if (!_isInitialLoadComplete) return false;
    
    // If the user has never provided measurements, we DO need an initial update
    if (_weight <= 0 || _height <= 10) return true;
    
    // If we have no update date, something is wrong with the DB record, prompt once.
    if (_lastBmiUpdate == null) return true;
    
    final difference = DateTime.now().difference(_lastBmiUpdate!);
    int daysRequired;
    
    switch (_bmiUpdateFrequency) {
      case 'everyday':
        daysRequired = 1;
        break;
      case '3_days':
        daysRequired = 3;
        break;
      case 'weekly':
        daysRequired = 7;
        break;
      case 'biweekly':
        daysRequired = 14;
        break;
      case 'monthly':
        daysRequired = 30;
        break;
      default:
        daysRequired = 7;
    }
    
    return difference.inDays >= daysRequired;
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // Timer Methods
  void startTimer(String workoutName) {
    if (_isTimerRunning && _activeWorkoutName == workoutName) return;
    
    _activeWorkoutName = workoutName;
    _isTimerRunning = true;
    _globalTimer?.cancel();
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseTimer() {
    _isTimerRunning = false;
    _globalTimer?.cancel();
    notifyListeners();
  }

  void resetTimer() {
    _isTimerRunning = false;
    _globalTimer?.cancel();
    _timerSeconds = 0;
    _activeWorkoutName = null;
    notifyListeners();
  }

  // Unified Calorie Calculation Logic
  static double calculateBurnRate(double weight, double met) {
    double weightVal = weight > 0 ? weight : 70.0;
    return (met * 3.5 * weightVal) / 200;
  }

  static double getMetForWorkout(String workoutName) {
    String name = workoutName.toLowerCase();
    if (name.contains('run')) return 10.0;
    if (name.contains('walk')) return 3.5;
    if (name.contains('cycl')) return 8.0;
    if (name.contains('swim')) return 7.0;
    if (name.contains('push') || name.contains('sit') || name.contains('calisthenics')) return 8.0;
    return 6.0;
  }

  double calculateBurnedCalories() {
    final catalogItem = _workoutCatalog.firstWhere(
      (item) => item['name'] == _activeWorkoutName,
      orElse: () => {},
    );

    if (catalogItem.isNotEmpty) {
      return (catalogItem['calories_per_minute'] as num).toDouble() * (_timerSeconds / 60);
    }

    double met = getMetForWorkout(_activeWorkoutName ?? 'General');
    double burnPerMin = calculateBurnRate(_weight, met);
    return burnPerMin * (_timerSeconds / 60);
  }

  double get bmi {
    if (_height <= 10 || _weight <= 0) return 0;
    double heightInMeters = _height / 100;
    return _weight / (heightInMeters * heightInMeters);
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  List<FoodDiaryItem> get selectedDateFoodItems {
    return _foodItems
        .where((item) => _isSameDay(item.dateTime, _selectedDate))
        .toList();
  }

  List<Map<String, dynamic>> get selectedDateWorkoutItems {
    return _workoutItems
        .where((item) => _isSameDay(DateTime.parse(item['created_at']), _selectedDate))
        .toList();
  }

  double get totalCalories => selectedDateFoodItems
      .fold(0, (sum, item) => sum + item.calories);

  double get totalBurnedCalories {
    return selectedDateWorkoutItems
        .fold(0, (sum, item) => sum + (item['calories_burned'] ?? 0).toDouble());
  }
      
  double get totalProtein => selectedDateFoodItems
      .fold(0, (sum, item) => sum + item.protein);
      
  double get totalCarbs => selectedDateFoodItems
      .fold(0, (sum, item) => sum + item.carbs);
      
  double get totalFat => selectedDateFoodItems
      .fold(0, (sum, item) => sum + item.fat);

  final _supabase = Supabase.instance.client;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _fetchAllData();
      } else {
        _clearData();
      }
    });

    if (_supabase.auth.currentUser != null) {
      _fetchAllData();
    }
  }

  Future<void> _fetchAllData() async {
    _isLoading = true;
    _isInitialLoadComplete = false;
    notifyListeners();
    
    try {
      debugPrint('Supabase: Starting data fetch...');
      await Future.wait([
        fetchUserProfile(notify: false).catchError((e) => debugPrint('Error Profile: $e')),
        fetchFoodItems(notify: false).catchError((e) => debugPrint('Error Food: $e')),
        fetchWorkoutItems(notify: false).catchError((e) => debugPrint('Error History: $e')),
        fetchWorkoutCatalog(notify: false).catchError((e) => debugPrint('Error Catalog: $e')),
        fetchBmiHistory(notify: false).catchError((e) => debugPrint('Error BMI History: $e')),
      ]);
      _isInitialLoadComplete = true;
      debugPrint('Supabase: Data fetch complete.');
    } catch (e) {
      debugPrint('Supabase Critical Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearData() {
    _foodItems.clear();
    _workoutItems.clear();
    _workoutCatalog.clear();
    _bmiHistory.clear();
    _calorieGoal = 2500;
    _weight = 0;
    _height = 0;
    _age = 0;
    _displayName = '';
    _email = '';
    _lastBmiUpdate = null;
    _bmiUpdateFrequency = 'weekly';
    _isInitialLoadComplete = false;
    resetTimer();
    notifyListeners();
  }

  Future<void> fetchUserProfile({bool notify = true}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      if (data != null) {
        _calorieGoal = data['calorie_goal'] ?? 2500;
        _weight = (data['weight_kg'] ?? 0).toDouble();
        _height = (data['height_cm'] ?? 0).toDouble();
        _age = data['age'] ?? 0;
        _displayName = data['display_name'] ?? '';
        _email = data['email'] ?? user.email ?? '';
        _bmiUpdateFrequency = data['bmi_update_frequency'] ?? 'weekly';
        
        // Use last_bmi_update, fallback to record creation date if missing
        if (data['last_bmi_update'] != null) {
          _lastBmiUpdate = DateTime.parse(data['last_bmi_update']);
        } else if (data['created_at'] != null) {
          _lastBmiUpdate = DateTime.parse(data['created_at']);
        } else {
          _lastBmiUpdate = null;
        }
      } else {
        final now = DateTime.now();
        await _supabase.from('user_profiles').insert({
          'user_id': user.id,
          'email': user.email,
          'calorie_goal': 2500,
          'bmi_update_frequency': 'weekly',
          'last_bmi_update': now.toIso8601String(), // Initialize clock now
        });
        _lastBmiUpdate = now;
        _email = user.email ?? '';
      }
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      rethrow;
    }
  }

  Future<void> fetchWorkoutCatalog({bool notify = true}) async {
    try {
      final data = await _supabase.from('workout_catalog').select().order('name');
      _workoutCatalog.clear();
      _workoutCatalog.addAll(List<Map<String, dynamic>>.from(data));
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error fetching workout catalog: $e');
      rethrow;
    }
  }

  Future<void> fetchBmiHistory({bool notify = true}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('bmi_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      _bmiHistory.clear();
      _bmiHistory.addAll(List<Map<String, dynamic>>.from(data));
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error fetching BMI history: $e');
      rethrow;
    }
  }

  Future<void> logBmiUpdate(double weight, {double? height}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> data = {
        'user_id': user.id,
        'weight_kg': weight,
      };
      if (height != null && height > 0) {
        data['height_cm'] = height;
      }

      await _supabase.from('bmi_history').insert(data);
      await fetchUserProfile();
      await fetchBmiHistory();
    } catch (e) {
      debugPrint('Error logging BMI: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({String? name, double? weight, double? height, int? age, int? goal, String? frequency}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final updates = <String, dynamic>{'user_id': user.id};
      if (name != null) updates['display_name'] = name;
      if (weight != null) updates['weight_kg'] = weight;
      if (height != null) updates['height_cm'] = height;
      if (age != null) updates['age'] = age;
      if (goal != null) updates['calorie_goal'] = goal;
      if (frequency != null) updates['bmi_update_frequency'] = frequency;

      if (weight != null || height != null) {
        updates['last_bmi_update'] = DateTime.now().toIso8601String();
        _lastBmiUpdate = DateTime.now();
      }

      await _supabase.from('user_profiles').upsert(updates);
      
      if (name != null) _displayName = name;
      if (weight != null) _weight = weight;
      if (height != null) _height = height;
      if (age != null) _age = age;
      if (goal != null) _calorieGoal = goal;
      if (frequency != null) _bmiUpdateFrequency = frequency;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> fetchFoodItems({bool notify = true}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('food_diary')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      _foodItems.clear();
      for (var item in data) {
        _foodItems.add(FoodDiaryItem(
          name: item['name'] ?? 'Unknown',
          calories: (item['calories'] ?? 0).toDouble(),
          protein: (item['protein'] ?? 0).toDouble(),
          carbs: (item['carbs'] ?? 0).toDouble(),
          fat: (item['fat'] ?? 0).toDouble(),
          dateTime: DateTime.parse(item['created_at']).toLocal(),
          exerciseSuggestions: item['exercise_suggestions'] ?? "",
        ));
      }
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error fetching food items: $e');
      rethrow;
    }
  }

  Future<void> fetchWorkoutItems({bool notify = true}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('workout_diary')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      _workoutItems.clear();
      _workoutItems.addAll(List<Map<String, dynamic>>.from(data));
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error fetching workout items: $e');
      rethrow;
    }
  }

  Future<void> addFoodItem(String name, double calories, {double protein = 0, double carbs = 0, double fat = 0, String exerciseSuggestions = ""}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase.from('food_diary').insert({
        'user_id': user.id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'exercise_suggestions': exerciseSuggestions,
      }).select().single();

      _foodItems.insert(0, FoodDiaryItem(
        name: response['name'],
        calories: (response['calories']).toDouble(),
        protein: (response['protein']).toDouble(),
        carbs: (response['carbs']).toDouble(),
        fat: (response['fat']).toDouble(),
        dateTime: DateTime.parse(response['created_at']).toLocal(),
        exerciseSuggestions: response['exercise_suggestions'],
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding food item: $e');
    }
  }

  Future<void> addWorkoutItem(String name, int durationSeconds, double caloriesBurned) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase.from('workout_diary').insert({
        'user_id': user.id,
        'workout_name': name,
        'duration_seconds': durationSeconds,
        'calories_burned': caloriesBurned,
      }).select().single();

      _workoutItems.insert(0, response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding workout item: $e');
    }
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }

  void removeFoodItem(int index) {
    _foodItems.removeAt(index);
    notifyListeners();
  }
}
