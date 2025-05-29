import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Database/localDatabase.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/goal_input/goalInput.dart';
import 'package:moneymanager/aisupport/goal_input/ProgressManagerScreen.dart';
import 'package:moneymanager/aisupport/models/daily_task_hive.dart';
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
  String _currentGoalName =
      "Default Goal"; // You'll need a way to select/set the current goal

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; //
    _loadTasksForCurrentGoal();
  }

  // Inside _financialGoalState class

// ... (existing initState, _loadTasksForCurrentGoal, _getTasksForDay etc.)

  Future<void> _handleTaskDroppedOnCalendar(DailyTaskHive droppedTask,
      String originalPlanGoalName, DateTime targetDate) async {
    UserPlanHive? plan = _localDbService.getUserPlan(originalPlanGoalName);
    if (plan == null) {
      print("Error: Plan '$originalPlanGoalName' not found for updating task.");
      return;
    }

    bool taskUpdated = false;
    for (var phase in plan.phases) {
      for (var mTask in phase.monthlyTasks) {
        for (var wTask in mTask.weeklyTasks) {
          for (int i = 0; i < wTask.dailyTasks.length; i++) {
            if (wTask.dailyTasks[i].id == droppedTask.id) {
              // Update the actual DailyTaskHive object within the plan
              wTask.dailyTasks[i].dueDate = targetDate;
              // You might want to change the status to indicate it's scheduled
              wTask.dailyTasks[i].status =
                  'scheduled_on_calendar'; // Example status
              taskUpdated = true;
              print(
                  "Task '${wTask.dailyTasks[i].title}' updated to $targetDate in plan '${plan.goalName}'");
              break;
            }
          }
          if (taskUpdated) break;
        }
        if (taskUpdated) break;
      }
      if (taskUpdated) break;
    }

    if (taskUpdated) {
      await _localDbService.saveUserPlan(plan);
      // Refresh the UI. This will cause getTasksForThisWeek to re-filter
      // and _getTasksForDay for the calendar to pick up the new date.
      setState(() {
        _loadTasksForCurrentGoal(); // Reloads _tasks for the calendar
        // getTasksForThisWeek will be rebuilt by the build method due to setState
      });
    } else {
      print(
          "Error: Task with id '${droppedTask.id}' not found in plan '$originalPlanGoalName' after attempting to update.");
    }
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
              final dateKey = DateTime.utc(
                  dTask.dueDate.year, dTask.dueDate.month, dTask.dueDate.day);
              if (loadedTasks[dateKey] == null) {
                loadedTasks[dateKey] = [];
              }
              loadedTasks[dateKey]!.add(taskForCalendar);
            }
          }
        }
      }
    } else {
      print(
          "Plan '$_currentGoalName' not found in local DB for calendar view.");
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
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  builder: (context) {
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
          child: ListView(
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
                calendarBuilders: CalendarBuilders(
                  // You need to provide builders for all day types you want to be drop targets
                  // defaultBuilder, selectedBuilder, todayBuilder, outsideBuilder, weekendBuilder etc.
                  // Here's an example for defaultBuilder. Apply similarly to others.

                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(day, focusedDay);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    // You can add specific styling for today, then wrap with DragTarget
                    return _buildCalendarDayCell(day, focusedDay,
                        isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(day, focusedDay,
                        isSelected: true);
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    // For days outside the current month, usually non-interactive
                    // Or make them drag targets too if needed.
                    return Opacity(
                      opacity: 0.5, // Example: dim them
                      child: _buildCalendarDayCell(day, focusedDay,
                          isOutside: true),
                    );
                  },
                  // Add other builders like weekendBuilder if you have specific styles
                ),
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
                  outsideTextStyle:
                      TextStyle(color: Colors.white.withOpacity(0.4)),
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFF8A2BE2),
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6.0,
                  markersMaxCount: 3, // Max number of dots
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
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

              _selectedDay == null
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
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _getTasksForDay(_selectedDay!).length,
                          itemBuilder: (context, index) {
                            final task = _getTasksForDay(_selectedDay!)[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 4.0),
                              child: Card(
                                color: const Color(
                                    0xFF2A2A2A), // Slightly lighter dark for task cards
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  title: Text(
                                    task.taskName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    'Status: ${task.status}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7)),
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

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            GoalInputPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.ease;

                          final tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));

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

  Widget _buildCalendarDayCell(DateTime day, DateTime focusedDay,
      {bool isToday = false, bool isSelected = false, bool isOutside = false}) {
    // Basic day cell appearance (you can customize this further)
    final text = '${day.day}';
    TextStyle textStyle = const TextStyle(color: Colors.white);
    BoxDecoration decoration = const BoxDecoration();

    if (isOutside) {
      textStyle = TextStyle(color: Colors.white.withOpacity(0.4));
    }
    if (isSelected) {
      decoration =
          const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle);
      textStyle = const TextStyle(color: Colors.white);
    } else if (isToday) {
      decoration = BoxDecoration(
          color: Color(0xFF5A5A5A).withOpacity(0.5), shape: BoxShape.circle);
    }

    return DragTarget<Map<String, dynamic>>(
      // Expecting the Map from Draggable
      builder: (BuildContext context, List<dynamic> accepted,
          List<dynamic> rejected) {
        // This is the visual representation of the day cell
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4.0),
          alignment: Alignment.center,
          decoration: decoration.copyWith(
              border: accepted.isNotEmpty
                  ? Border.all(color: Colors.greenAccent, width: 2)
                  : null // Visual feedback on hover
              ),
          child: Text(text, style: textStyle),
        );
      },
      onWillAcceptWithDetails: (details) {
        // You can use this to provide feedback when a draggable is over the target
        // e.g., change the border color or background of the cell
        // For this example, the builder's 'accepted.isNotEmpty' handles some feedback
        return true; // Must return true to allow the drop
      },
      onAcceptWithDetails: (details) {
        final Map<String, dynamic> droppedData = details.data;
        final DailyTaskHive taskToAssign = droppedData['task'] as DailyTaskHive;
        final String planGoalName = droppedData['planGoalName'] as String;

        print(
            'Task "${taskToAssign.title}" dropped on $day from plan "$planGoalName"');
        _handleTaskDroppedOnCalendar(taskToAssign, planGoalName, day);
      },
    );
  }

  Widget getTasksForThisWeek() {
    List<Map<String, dynamic>> draggableTaskItems =
        []; // Store task and its plan's goalName

    final allPlans = _localDbService.getAllUserPlans();

    for (var plan in allPlans) {
      for (var phase in plan.phases) {
        for (var mTask in phase.monthlyTasks) {
          for (var wTask in mTask.weeklyTasks) {
            for (var dTask in wTask.dailyTasks) {
              // *** ADD FILTER HERE: Only include tasks that are not yet scheduled on the calendar ***
              if (dTask.status != 'scheduled_on_calendar') {
                // Example filter
                draggableTaskItems.add({
                  'task': dTask, // The DailyTaskHive object
                  'planGoalName': plan.goalName,
                });
              }
            }
          }
        }
      }
    }

    // Sort if needed (your existing sort logic was for Task objects, adapt if necessary)
    // For DailyTaskHive, it would be:
    draggableTaskItems.sort((a, b) => (a['task'] as DailyTaskHive)
        .dueDate
        .compareTo((b['task'] as DailyTaskHive).dueDate));

    if (draggableTaskItems.isEmpty) {
      return SizedBox(
          height: 134, // Matching your original height
          child: Center(
              child: Text("No tasks to schedule.",
                  style: TextStyle(color: Colors.white54))));
    }

    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxHeight: 134), // Your specified height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: draggableTaskItems.length,
        itemBuilder: (context, index) {
          final taskData = draggableTaskItems[index];
          final DailyTaskHive task = taskData['task'] as DailyTaskHive;

          // This is the visual representation of the task in the list
          Widget taskItemWidget = Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0), // Reduced horizontal for more items
            child: GestureDetector(
              onTap: () {/* Your existing showDialog logic */},
              child: Container(
                width: 130, // Slightly wider for better feedback
                // ... (rest of your existing Container styling for the task item)
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D44),
                  borderRadius: BorderRadius.circular(14),
                  // ... boxShadow, border
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        // ... date container styling
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${task.dueDate.day}/${task.dueDate.month}', // Display current/placeholder date
                          style: const TextStyle(
                              color: Colors.deepPurpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.title, // Use task.title from DailyTaskHive
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          return Draggable<Map<String, dynamic>>(
            data:
                taskData, // Pass the map containing DailyTaskHive and planGoalName
            feedback: Material(
                // Wrap feedback in Material for correct themeing
                elevation: 4.0,
                color: Colors
                    .transparent, // Transparent so only the item is visible
                child: ConstrainedBox(
                  // Ensure feedback has constraints
                  constraints:
                      BoxConstraints(maxWidth: 150), // Slightly larger feedback
                  child: taskItemWidget, // Use a copy of the item as feedback
                )),
            childWhenDragging: Container(
              // Placeholder when dragging
              width: 130, // Match item width
              margin:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: taskItemWidget, // The actual item
          );
        },
      ),
    );
  }
}
