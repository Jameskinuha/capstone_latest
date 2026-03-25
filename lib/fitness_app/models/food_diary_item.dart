class FoodDiaryItem {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime dateTime;
  final String exerciseSuggestions;

  FoodDiaryItem({
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    required this.dateTime,
    this.exerciseSuggestions = "",
  });
}
