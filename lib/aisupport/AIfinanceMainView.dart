import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moneymanager/aisupport/Database/localDatabase.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/goal_input/goalInput.dart';
import 'package:moneymanager/aisupport/goal_input/ProgressManagerScreen.dart';
import 'package:moneymanager/aisupport/models/daily_task_hive.dart';
import 'package:moneymanager/aisupport/taskModel.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart';
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
  bool hasGoal = true; // Assume true initially, will be checked

  final LocalDatabaseService _localDbService = LocalDatabaseService();
  Map<DateTime, List<Task>> _tasks = {};
  String _currentGoalName = "Default Goal";

    BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadCurrentGoalNameAndTasks(); // Consolidated loading
    _checkIfUserAlreadyHasGoal(); // Check Firestore for goal existence
    _loadBannerAd();
  }

    void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Ad Unit ID
      // Replace with your actual ad unit ID for production
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          print('BannerAd failed to load: $error');
        },
        onAdOpened: (Ad ad) => print('BannerAd opened.'),
        onAdClosed: (Ad ad) => print('BannerAd closed.'),
        onAdImpression: (Ad ad) => print('BannerAd impression.'),
      ),
    )..load();
  }


  // Consolidated method to load goal name and then tasks
  Future<void> _loadCurrentGoalNameAndTasks() async {
    await _localDbService.init(); // Ensure Hive is initialized
    final allPlans = _localDbService.getAllUserPlans();
    if (allPlans.isNotEmpty) {
      // You might want a more sophisticated way to select the "current" goal
      // For now, let's assume the first plan is the current one.
      final currentPlan = allPlans.first;
      setState(() {
        _currentGoalName = currentPlan.goalName;
      });
      _loadTasksForCurrentGoal();
    } else {
      print("No local plans found. Displaying default or empty state.");
      setState(() {
        _currentGoalName = "No Goal Set"; // Or handle as appropriate
        _tasks = {};
        // Consider setting hasGoal to false if no local plans and no Firestore plans
      });
    }
  }


  Future<void> _checkIfUserAlreadyHasGoal() async {
    // This checks Firestore and might influence the `hasGoal` state,
    // particularly for UI elements like the FAB.
    final doc = await FirebaseFirestore.instance
        .collection('financialGoals')
        .doc(userId.uid)
        .get();

    bool firestoreGoalExists = false;
    if (doc.exists) {
      final goals = doc.data()?['goalNameList'];
      if (goals is List && goals.isNotEmpty) {
        firestoreGoalExists = true;
      }
    }

    // Update `hasGoal` based on local plans primarily,
    // or Firestore if local is empty.
    // This logic might need refinement based on your app's specific flow
    // for what "hasGoal" truly means (e.g., ability to create new vs. manage existing).
    final localPlansExist = _localDbService.getAllUserPlans().isNotEmpty;

    setState(() {
      // If there's a local plan, they definitely have a goal they are working with.
      // If no local plan, but a goal exists in Firestore (perhaps not yet cached locally),
      // they still "have a goal" in a broader sense.
      hasGoal = localPlansExist || firestoreGoalExists;
      if (!localPlansExist && !firestoreGoalExists) {
        print('User does not have any goal (local or Firestore).');
      } else if (localPlansExist) {
        print('User has at least one local goal.');
      } else {
        print('User has a goal in Firestore but no local plans detected yet.');
      }
    });
  }


  Future<void> _handleTaskDroppedOnCalendar(DailyTaskHive droppedTask,
      String originalPlanGoalName, DateTime targetDate) async {
    UserPlanHive? plan = _localDbService.getUserPlan(originalPlanGoalName);
    if (plan == null) {
      print("Error: Plan '$originalPlanGoalName' not found for updating task.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Error: Plan '$originalPlanGoalName' not found.")));
      return;
    }

    bool taskUpdated = false;
    // Normalize targetDate to UTC to match how dates might be stored or compared
    final normalizedTargetDate = DateTime.utc(targetDate.year, targetDate.month, targetDate.day);

    for (var phase in plan.phases) {
      for (var mTask in phase.monthlyTasks) {
        for (var wTask in mTask.weeklyTasks) {
          for (int i = 0; i < wTask.dailyTasks.length; i++) {
            if (wTask.dailyTasks[i].id == droppedTask.id) {
              // Update the actual DailyTaskHive object within the plan
              wTask.dailyTasks[i].dueDate = normalizedTargetDate; // Use normalized date
              wTask.dailyTasks[i].status =
                  'scheduled_on_calendar';
              taskUpdated = true;
              print(
                  "Task '${wTask.dailyTasks[i].title}' updated to $normalizedTargetDate in plan '${plan.goalName}'");
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
      print("Plan '${plan.goalName}' saved successfully after task update.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Task '${droppedTask.title}' scheduled on ${targetDate.toLocal().toString().split(' ')[0]}")));
      // Reload tasks for the current goal to refresh the calendar and lists
      _loadTasksForCurrentGoal();
    } else {
      print(
          "Error: Task with id '${droppedTask.id}' not found in plan '$originalPlanGoalName' after attempting to update.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Error: Task '${droppedTask.title}' not found in the plan.")));
    }
  }

  void _loadTasksForCurrentGoal() {
    UserPlanHive? plan = _localDbService.getUserPlan(_currentGoalName);
    Map<DateTime, List<Task>> loadedTasks = {};

    if (plan != null) {
      for (var phase in plan.phases) {
        for (var mTask in phase.monthlyTasks) {
          for (var wTask in mTask.weeklyTasks) {
            for (var dTask in wTask.dailyTasks) {
              final taskForCalendar = Task(
                taskId: dTask.id,
                taskName: dTask.title,
                dueDate: dTask.dueDate,
                status: dTask.status,
              );
              // IMPORTANT: Ensure the key for the map is UTC if dueDates are UTC.
              // TableCalendar typically works well with UTC dates for events.
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
      print("Plan '$_currentGoalName' not found in local DB for calendar view.");
    }

    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _tasks = loadedTasks;
      });
    }
  }

  List<Task> _getTasksForDay(DateTime day) {
    DateTime normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _tasks[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        centerTitle: true,
        title: const Text(
          'Financial Goal',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black, // Use a defined color for consistency
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView( // Changed to Column for better structure
            children: [
              Text(
                '$_currentGoalName', // Display current goal name
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 20, // Increased size
                  fontWeight: FontWeight.w500, // Medium weight
                ),
                textAlign: TextAlign.start,
              ),
              
              const SizedBox(height: 8),
              getTasksForThisWeek(), // This is the horizontal list of draggable tasks
              const SizedBox(height: 24), // Adjusted spacing
              GestureDetector(
                onTap: () {
                    showModalBottomSheet(
                      enableDrag: true,
                      showDragHandle: true,
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        minChildSize: 0.4,
                        maxChildSize: 0.9,
                        expand: false,
                        builder: (context, scrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          ),
                          child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: ProgressManagerScreen(),
                          ),
                        );
                        },
                      );
                      },
                    );
                    },
                  
                child:Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.withOpacity(0.85),
                    Colors.deepPurpleAccent.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.25),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                  ],
                  border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.5),
                  width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                  Text(
                    "Review my plan",
                    style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.flag, color: Colors.white),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
                ),
              ),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
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
                eventLoader: _getTasksForDay,
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(day, focusedDay);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(day, focusedDay,
                        isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildCalendarDayCell(day, focusedDay,
                        isSelected: true);
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    return Opacity(
                      opacity: 0.5,
                      child: _buildCalendarDayCell(day, focusedDay,
                          isOutside: true),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: const BoxDecoration(
                    color: Color(0xFF5A5A5A),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle:
                      const TextStyle(color: Colors.redAccent),
                  outsideTextStyle:
                      TextStyle(color: Colors.white.withOpacity(0.4)),
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFF8A2BE2),
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6.0,
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white70),
                  weekendStyle: TextStyle(color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 16),
              // Display tasks for the selected day
              _buildSelectedDayTasks(),
              
              //advertisement 
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (hasGoal) { // `hasGoal` is updated by `_checkIfUserAlreadyHasGoal`
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Subscription Required'),
                content: const Text(
                  'You need a subscription to create more goals.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => GoalInputPage()),
            );
            // If a new goal might have been created, reload relevant data.
            if (result == true) { // Assuming GoalInputPage returns true on successful goal creation
              _loadCurrentGoalNameAndTasks();
              _checkIfUserAlreadyHasGoal();
            }
          }
        },
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSelectedDayTasks() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a day to view tasks.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    final tasksForSelectedDay = _getTasksForDay(_selectedDay!);
    if (tasksForSelectedDay.isEmpty) {
      return const Center(
        child: Text(
          'No tasks for this day.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    // Using a Column directly if the number of tasks per day is small,
    // or ListView if it can be long.
    // For simplicity, using Column, assuming not too many tasks on one day.
    return Column( // Changed from ListView.builder to prevent nested scrolling issues
      children: tasksForSelectedDay.map((task) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Card(
            color: const Color(0xFF2A2A2A),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                task.taskName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Status: ${task.status}',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              onTap: () {
                print('Tapped on task: ${task.taskName}');
                // Potentially show task details dialog
              },
            ),
          ),
        );
      }).toList(),
    );
  }


  Widget _buildCalendarDayCell(DateTime day, DateTime focusedDay,
      {bool isToday = false, bool isSelected = false, bool isOutside = false}) {
    final text = '${day.day}';
    TextStyle textStyle = const TextStyle(color: Colors.white);
    BoxDecoration decoration = const BoxDecoration();

    if (isOutside) {
      textStyle = TextStyle(color: Colors.white.withOpacity(0.4));
    }
    if (isSelected) {
      decoration =
          const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle);
      textStyle = const TextStyle(color: Colors.white); // Ensure text is visible
    } else if (isToday) {
      decoration = BoxDecoration(
          color: Color(0xFF5A5A5A).withOpacity(0.5), shape: BoxShape.circle);
    }

    return DragTarget<Map<String, dynamic>>(
      builder: (BuildContext context, List<dynamic> accepted,
          List<dynamic> rejected) {
        bool isHovered = accepted.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4.0),
          alignment: Alignment.center,
          decoration: decoration.copyWith(
            border: isHovered
                ? Border.all(color: Colors.greenAccent, width: 2.5) // Thicker border
                : (isSelected || isToday ? null : Border.all(color: Colors.white24, width: 0.5)), // Subtle border for other days
            boxShadow: isHovered ? [
                BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2
                )
            ] : [],
          ),
          child: Text(text, style: textStyle),
        );
      },
      onWillAcceptWithDetails: (details) {
        // You can add more sophisticated logic here if needed
        return true; // Allow drop
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
    List<Map<String, dynamic>> draggableTaskItems = [];

    // Filter for the current goal only, if a specific goal is selected for the calendar view
    // Otherwise, it will show draggable tasks from all plans, which might be confusing.
    UserPlanHive? currentPlan = _localDbService.getUserPlan(_currentGoalName);

    if (currentPlan != null) {
        for (var phase in currentPlan.phases) {
            for (var mTask in phase.monthlyTasks) {
                for (var wTask in mTask.weeklyTasks) {
                    for (var dTask in wTask.dailyTasks) {
                        if (dTask.status != 'scheduled_on_calendar' && dTask.status != 'completed') {
                            draggableTaskItems.add({
                                'task': dTask,
                                'planGoalName': currentPlan.goalName, // Associate with the current plan
                            });
                        }
                    }
                }
            }
        }
    }


    draggableTaskItems.sort((a, b) => (a['task'] as DailyTaskHive)
        .dueDate // Or some other priority field if dueDate isn't set for unscheduled
        .compareTo((b['task'] as DailyTaskHive).dueDate));

    if (draggableTaskItems.isEmpty) {
      return SizedBox(
          height: 134,
          child: Center(
              child: Text("No tasks to schedule for $_currentGoalName.",
                  style: TextStyle(color: Colors.white54))));
    }

    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxHeight: 162), // Increased height slightly
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: draggableTaskItems.length,
        itemBuilder: (context, index) {
          final taskData = draggableTaskItems[index];
          final DailyTaskHive task = taskData['task'] as DailyTaskHive;

          Widget taskItemWidget = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
            child: Container(
              width: 140, // Slightly wider
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D44), // Task item color
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0,2),
                  )
                ]
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.25), // More vibrant
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // Display placeholder or original due date before scheduling
                        task.status == 'pending' ? "Unscheduled" : '${task.dueDate.day}/${task.dueDate.month}',
                        style: const TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                     const SizedBox(height: 4),
                      Text(
                        taskData['planGoalName'], // Show which plan it belongs to
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ),
          );

          // Using LongPressDraggable for long press to drag
          return LongPressDraggable<Map<String, dynamic>>(
            data: taskData,
            feedback: Material(
                elevation: 4.0,
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: taskItemWidget, // Show the same widget as feedback
                )),
            childWhenDragging: Container( // Placeholder when dragging
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0), // Adjusted margin
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(Icons.drag_handle, color: Colors.white24)), // Optional: show drag handle or similar
            ),
            child: taskItemWidget, // The actual item
            onDragStarted: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Dragging '${task.title}'... Drop on a calendar day."),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.blueGrey,
                    )
                 );
            },
          );
        },
      ),
    );
  }
}