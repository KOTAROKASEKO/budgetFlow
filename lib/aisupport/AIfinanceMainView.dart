
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Database/localDatabase.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/goal_input/goalInput.dart';
import 'package:moneymanager/aisupport/goal_input/ProgressManagerScreen.dart';
import 'package:moneymanager/aisupport/taskModel.dart';
import 'package:table_calendar/table_calendar.dart';

class financialGoal extends StatefulWidget {
  const financialGoal({super.key});

  @override
  State<financialGoal> createState() => _financialGoalState();
}

class _financialGoalState extends State<financialGoal> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay; // Nullable for initial state
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Dummy Task Data - In a real app, this would come from a state management solution or backend
final LocalDatabaseService _localDbService = LocalDatabaseService();
Map<DateTime, List<Task>> _tasks = {}; // Keep this, but populate from Hive
String _currentGoalName = "Default Goal"; // You'll need a way to select/set the current goal

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; //
    _loadTasksForCurrentGoal();
  }

  void _loadTasksForCurrentGoal() {
    // Assuming you have a way to set/get the active _currentGoalName
    UserPlanHive? plan = _localDbService.getUserPlan(_currentGoalName);
    Map<DateTime, List<Task>> loadedTasks = {};

    if (plan != null) {
      for (var phase in plan.phases) {
        for (var mTask in phase.monthlyTasks) {
          for (var wTask in mTask.weeklyTasks) {
            for (var dTask in wTask.dailyTasks) {
              // Convert DailyTaskHive to the Task model required by TableCalendar's eventLoader
              final taskForCalendar = Task(
                taskId: dTask.id, //
                taskName: dTask.title, //
                dueDate: dTask.dueDate, //
                status: dTask.status, //
              );
              final dateKey = DateTime.utc(dTask.dueDate.year, dTask.dueDate.month, dTask.dueDate.day);
              if (loadedTasks[dateKey] == null) {
                loadedTasks[dateKey] = [];
              }
              loadedTasks[dateKey]!.add(taskForCalendar);
            }
          }
        }
      }
    } else {
      print("Plan '$_currentGoalName' not found in local DB for calendar view.");
      // Optionally, implement Firestore fallback here as well
    }

    setState(() {
      _tasks = loadedTasks; //
      // Update currentGoalStatus based on whether tasks were loaded
    });
  }


  // Helper function to get tasks for a given day
  List<Task> _getTasksForDay(DateTime day) {
    // Normalize the date to UTC to match keys in _tasks map
    // TableCalendar's focusedDay and selectedDay are often UTC
    DateTime normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _tasks[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Determine the current goal status (replace with actual logic)
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Financial Goal',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(context: context, builder: (context){
                return ProgressManagerScreen();
              });
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1A1A1A), // Dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current goal:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
            getTasksForThisWeek(),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black, // Darker block for calendar
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) {
                          // Use isSameDay to check if a day is selected
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay; // Update focused day
                          });
                        },
                        onFormatChanged: (format) {
                          if (_calendarFormat != format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          }
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        eventLoader: _getTasksForDay, // Pass the event loader
                        // Customize calendar style for dark theme
                        calendarStyle: CalendarStyle(
                          todayDecoration: const BoxDecoration(
                            color: Color(0xFF5A5A5A), // Slightly lighter dark for today
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Colors.blueAccent, // Vibrant blue for selected day
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: const TextStyle(color: Colors.white),
                          weekendTextStyle: const TextStyle(color: Colors.redAccent),
                          outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          markerDecoration: const BoxDecoration(
                            color: Color(0xFF8A2BE2), // Purple marker for tasks
                            shape: BoxShape.circle,
                          ),
                          markerSize: 6.0,
                          markersMaxCount: 3, // Max number of dots
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          // leftWithIcon: true,
                          // rightWithIcon: true,
                          // leftIcon: Icon(Icons.chevron_left, color: Colors.white),
                          // rightIcon: Icon(Icons.chevron_right, color: Colors.white),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: Colors.white70),
                          weekendStyle: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Display tasks for the selected day
                      Expanded(
                        child: _selectedDay == null
                            ? const Center(
                                child: Text(
                                  'Select a day to view tasks.',
                                  style: TextStyle(color: Colors.white54, fontSize: 16),
                                ),
                              )
                            : _getTasksForDay(_selectedDay!).isEmpty
                                ? const Center(
                                    child: Text(
                                      'No tasks for this day.',
                                      style: TextStyle(color: Colors.white54, fontSize: 16),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _getTasksForDay(_selectedDay!).length,
                                    itemBuilder: (context, index) {
                                      final task = _getTasksForDay(_selectedDay!)[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                        child: Card(
                                          color: const Color(0xFF2A2A2A), // Slightly lighter dark for task cards
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ListTile(
                                            title: Text(
                                              task.taskName,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                            subtitle: Text(
                                              'Status: ${task.status}',
                                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                            ),
                                            // You can add more details or actions here
                                            onTap: () {
                                              // Handle task tap, e.g., show task details
                                              print('Tapped on task: ${task.taskName}');
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => GoalInputPage(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.ease;

                          final tween =
                              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  backgroundColor: Colors.blueAccent,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getTasksForThisWeek(){
    return ConstrainedBox(constraints: const BoxConstraints(maxHeight: 100),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          DateTime date = _tasks.keys.elementAt(index);
          List<Task> tasksForDate = _tasks[date] ?? [];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}/${date.month}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...tasksForDate.map((task) => Text(
                  task.taskName,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                )).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}