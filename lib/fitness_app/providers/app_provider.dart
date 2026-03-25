import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_diary_item.dart';
import 'package:intl/intl.dart';

class AppProvider with ChangeNotifier {
  final List<FoodDiaryItem> _foodItems = [];
  bool _isLoading = false;
  
  // User Profile Data
  int _calorieGoal = 2500;
  double _weight = 0;
  double _height = 0;
  int _age = 0;
  String _displayName = '';
  String _email = '';

  DateTime _selectedDate = DateTime.now();

  List<FoodDiaryItem> get foodItems => _foodItems;
  bool get isLoading => _isLoading;
  
  int get calorieGoal => _calorieGoal;
  double get weight => _weight;
  double get height => _height;
  int get age => _age;
  String get displayName => _displayName;
  String get email => _email;

  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
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
    final items = _foodItems
        .where((item) => _isSameDay(item.dateTime, _selectedDate))
        .toList();
    debugPrint('AppProvider: Found ${items.length} items for ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
    return items;
  }

  double get totalCalories => selectedDateFoodItems
      .fold(0, (sum, item) => sum + item.calories);
      
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
        fetchUserProfile();
        fetchFoodItems();
      } else {
        _clearData();
      }
    });

    if (_supabase.auth.currentUser != null) {
      fetchUserProfile();
      fetchFoodItems();
    }
  }

  void _clearData() {
    _foodItems.clear();
    _calorieGoal = 2500;
    _weight = 0;
    _height = 0;
    _age = 0;
    _displayName = '';
    _email = '';
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      debugPrint('AppProvider: Fetching profile for ${user.id}');
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
        debugPrint('AppProvider: Profile loaded: $_displayName');
      } else {
        debugPrint('AppProvider: Profile missing, creating default...');
        await _supabase.from('user_profiles').insert({
          'user_id': user.id,
          'email': user.email,
          'calorie_goal': 2500,
        });
        _email = user.email ?? '';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> updateProfile({String? name, double? weight, double? height, int? age, int? goal}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final updates = <String, dynamic>{
        'user_id': user.id,
      };
      if (name != null) updates['display_name'] = name;
      if (weight != null) updates['weight_kg'] = weight;
      if (height != null) updates['height_cm'] = height;
      if (age != null) updates['age'] = age;
      if (goal != null) updates['calorie_goal'] = goal;

      // Use upsert to handle case where row might not exist
      await _supabase.from('user_profiles').upsert(updates);
      
      if (name != null) _displayName = name;
      if (weight != null) _weight = weight;
      if (height != null) _height = height;
      if (age != null) _age = age;
      if (goal != null) _calorieGoal = goal;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> fetchFoodItems() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

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
      debugPrint('AppProvider: Fetched ${_foodItems.length} total food items');
    } catch (e) {
      debugPrint('Error fetching food items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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

  void removeFoodItem(int index) {
    _foodItems.removeAt(index);
    notifyListeners();
  }
}
