import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key, this.animationController}) : super(key: key);

  final AnimationController? animationController;

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  Animation<double>? topBarAnimation;
  DateTime _focusedDay = DateTime.now();
  double topBarOpacity = 0.0;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    topBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: widget.animationController!,
            curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn)));

    scrollController.addListener(() {
      if (scrollController.offset >= 24) {
        if (topBarOpacity != 1.0) {
          setState(() {
            topBarOpacity = 1.0;
          });
        }
      } else if (scrollController.offset <= 24 &&
          scrollController.offset >= 0) {
        if (topBarOpacity != scrollController.offset / 24) {
          setState(() {
            topBarOpacity = scrollController.offset / 24;
          });
        }
      } else if (scrollController.offset <= 0) {
        if (topBarOpacity != 0.0) {
          setState(() {
            topBarOpacity = 0.0;
          });
        }
      }
    });
    super.initState();
  }

  void _showDayDetailsDialog(DateTime date) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    final dayFoodItems = appProvider.foodItems
        .where((item) => DateUtils.isSameDay(item.dateTime, date))
        .toList();
        
    final dayWorkoutItems = appProvider.workoutItems
        .where((item) => DateUtils.isSameDay(DateTime.parse(item['created_at']), date))
        .toList();

    final totalEaten = dayFoodItems.fold(0.0, (sum, item) => sum + item.calories);
    final totalBurned = dayWorkoutItems.fold(0.0, (sum, item) => sum + (item['calories_burned'] ?? 0).toDouble());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE').format(date),
              style: TextStyle(
                fontSize: 14,
                color: FitnessAppTheme.grey.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              DateFormat('d MMMM yyyy').format(date),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: FitnessAppTheme.darkerText,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Daily Calories', '${totalEaten.toInt()} kcal', Colors.orange),
                _buildSummaryRow('Calories Burned', '${totalBurned.toInt()} kcal', Colors.red),
                const Divider(height: 32),
                if (dayFoodItems.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Food Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: FitnessAppTheme.darkerText)),
                  ),
                  ...dayFoodItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    'P: ${item.protein.toInt()}g | C: ${item.carbs.toInt()}g | F: ${item.fat.toInt()}g',
                                    style: TextStyle(fontSize: 11, color: FitnessAppTheme.grey.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                            Text('${item.calories.toInt()} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (item.exerciseSuggestions.isNotEmpty && item.exerciseSuggestions != "N/A")
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '💡 ${item.exerciseSuggestions}',
                              style: const TextStyle(fontSize: 10, color: FitnessAppTheme.nearlyDarkBlue, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  )),
                ],
                if (dayWorkoutItems.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(top: dayFoodItems.isNotEmpty ? 24 : 0, bottom: 8),
                    child: const Text('Workout Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: FitnessAppTheme.darkerText)),
                  ),
                  ...dayWorkoutItems.map((item) {
                    final int duration = item['duration_seconds'] ?? 0;
                    final int mins = duration ~/ 60;
                    final int secs = duration % 60;
                    final String timeStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['workout_name'] ?? 'Workout', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  'Duration: $timeStr',
                                  style: TextStyle(fontSize: 11, color: FitnessAppTheme.grey.withOpacity(0.6)),
                                ),
                              ],
                            ),
                          ),
                          Text('-${(item['calories_burned'] as num).toInt()} kcal', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    );
                  }),
                ],
                if (dayFoodItems.isEmpty && dayWorkoutItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 40, color: FitnessAppTheme.grey.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          Text('No data recorded for this day', style: TextStyle(color: FitnessAppTheme.grey.withOpacity(0.5))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: FitnessAppTheme.nearlyDarkBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: FitnessAppTheme.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FitnessAppTheme.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            getMainListViewUI(),
            getAppBarUI(),
            SizedBox(
              height: MediaQuery.of(context).padding.bottom,
            )
          ],
        ),
      ),
    );
  }

  Widget getMainListViewUI() {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(
        top: AppBar().preferredSize.height +
            MediaQuery.of(context).padding.top +
            24,
        bottom: 62 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _buildCalendarHeader(),
        _buildCalendarGrid(),
        const SizedBox(height: 24),
        _buildMonthlyStats(),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: const TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: FitnessAppTheme.darkerText,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOffset = DateTime(_focusedDay.year, _focusedDay.month, 1).weekday % 7;
    final appProvider = Provider.of<AppProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: FitnessAppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: FitnessAppTheme.grey.withOpacity(0.1),
              offset: const Offset(4, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => Text(d, style: TextStyle(color: FitnessAppTheme.grey.withOpacity(0.5), fontWeight: FontWeight.bold)))
                    .toList(),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: daysInMonth + firstDayOffset,
              itemBuilder: (context, index) {
                if (index < firstDayOffset) return const SizedBox();
                final day = index - firstDayOffset + 1;
                final date = DateTime(_focusedDay.year, _focusedDay.month, day);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                
                // Calculate calories for this day
                final dayCalories = appProvider.foodItems
                    .where((item) => DateUtils.isSameDay(item.dateTime, date))
                    .fold(0.0, (sum, item) => sum + item.calories);
                
                final dayBurned = appProvider.workoutItems
                    .where((item) => DateUtils.isSameDay(DateTime.parse(item['created_at']), date))
                    .fold(0.0, (sum, item) => sum + (item['calories_burned'] ?? 0).toDouble());

                return InkWell(
                  onTap: () {
                    appProvider.setSelectedDate(date);
                    _showDayDetailsDialog(date);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday ? FitnessAppTheme.nearlyDarkBlue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday ? Border.all(color: FitnessAppTheme.nearlyDarkBlue) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.darkerText,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (dayCalories > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 2, left: 1, right: 1),
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (dayBurned > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 2, left: 1, right: 1),
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final appProvider = Provider.of<AppProvider>(context);
    double monthlyTotal = 0;
    double monthlyBurned = 0;

    for (var item in appProvider.foodItems) {
      if (item.dateTime.month == _focusedDay.month && item.dateTime.year == _focusedDay.year) {
        monthlyTotal += item.calories;
      }
    }
    
    for (var item in appProvider.workoutItems) {
      DateTime workoutDate = DateTime.parse(item['created_at']);
      if (workoutDate.month == _focusedDay.month && workoutDate.year == _focusedDay.year) {
        monthlyBurned += (item['calories_burned'] ?? 0).toDouble();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Overview',
            style: TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: FitnessAppTheme.darkerText,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            'Total Intake',
            '${monthlyTotal.toInt()} kcal',
            Icons.restaurant,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Burned (Estimated)',
            '${monthlyBurned.toInt()} kcal',
            Icons.local_fire_department,
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Avg Daily Intake',
            '${(monthlyTotal / 30).toInt()} kcal',
            Icons.trending_up,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: FitnessAppTheme.grey.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: FitnessAppTheme.grey.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: FitnessAppTheme.darkerText),
          ),
        ],
      ),
    );
  }

  Widget getAppBarUI() {
    return Column(
      children: <Widget>[
        AnimatedBuilder(
          animation: widget.animationController!,
          builder: (BuildContext context, Widget? child) {
            return FadeTransition(
              opacity: topBarAnimation!,
              child: Transform(
                transform: Matrix4.translationValues(
                    0.0, 30 * (1.0 - topBarAnimation!.value), 0.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.white.withOpacity(topBarOpacity),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32.0),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: FitnessAppTheme.grey
                              .withOpacity(0.4 * topBarOpacity),
                          offset: const Offset(1.1, 1.1),
                          blurRadius: 10.0),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.of(context).padding.top,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16 - 8.0 * topBarOpacity,
                            bottom: 12 - 8.0 * topBarOpacity),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Monthly Progress',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22 + 6 - 6 * topBarOpacity,
                                    letterSpacing: 1.2,
                                    color: FitnessAppTheme.darkerText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        )
      ],
    );
  }
}
