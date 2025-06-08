// lib/aisupport/DashBoard_MapTask/View_AIRoadMap.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/ViewModel_AIRoadMap.dart';
import 'package:moneymanager/aisupport/RoadMaps/View_roadMapRecord.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/goal_input/goalInput.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';


class FinancialGoalPage extends StatelessWidget {
  const FinancialGoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Providerはmain.dartで提供されているので、ここではシンプルにViewを返すだけ
    return const FinancialGoalView();
  }
}

class FinancialGoalView extends StatefulWidget {
  const FinancialGoalView();
  @override
  State<FinancialGoalView> createState() => _FinancialGoalViewState();
}

class _FinancialGoalViewState extends State<FinancialGoalView> {
  final TextEditingController _noteController = TextEditingController();
  // **[NEW]** Scroll controller for auto-scrolling
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    final noteViewModel = context.read<NoteViewModel>();
    _noteController.text = noteViewModel.noteForSelectedDay?.content ?? '';
    noteViewModel.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    final noteViewModel = context.read<NoteViewModel>();
    if (_noteController.text !=
        (noteViewModel.noteForSelectedDay?.content ?? '')) {
      _noteController.text = noteViewModel.noteForSelectedDay?.content ?? '';
    }
  }

  // **[NEW]** Function to start scrolling programmatically
  void _startScrolling(double speed) {
    _stopScrolling();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final newOffset = _scrollController.offset + speed;
      if (newOffset < _scrollController.position.minScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _stopScrolling();
      } else if (newOffset > _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _stopScrolling();
      } else {
        _scrollController.jumpTo(newOffset);
      }
    });
  }

  // **[NEW]** Function to stop scrolling
  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  @override
  void dispose() {
    context.read<NoteViewModel>().removeListener(_onNoteChanged);
    _noteController.dispose();
    _scrollController.dispose();
    _stopScrolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AIFinanceViewModel>();
    final noteViewModel = context.watch<NoteViewModel>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        centerTitle: true,
        title: const Text('Financial Goal',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      // **[MODIFIED]** Wrap body in a Stack for auto-scroll targets
      body: viewModel.isLoading && viewModel.currentActiveGoal == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  child: ListView(
                    controller: _scrollController, // Assign scroll controller
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewModel.currentActiveGoal?.title ?? "No Goal Set",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.start,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              viewModel.currentActiveGoal?.title.isNotEmpty == true
                                  ? "Tap for the detail!! LongPress to drag to calendar!!"
                                  : '',
                              maxLines: 2,
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      _buildDraggableTasks(context, viewModel),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildReviewPlanButton(context),
                            const SizedBox(height: 16),
                            TableCalendar<TaskHiveModel>(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: viewModel.focusedDay,
                              calendarFormat: viewModel.calendarFormat,
                              // **[MODIFIED]** Allow parent ListView to scroll
                              availableGestures: AvailableGestures.horizontalSwipe,
                              selectedDayPredicate: (day) =>
                                  isSameDay(viewModel.selectedDay, day),
                              onDaySelected: viewModel.onDaySelected,
                              onFormatChanged: (format) {},
                              onPageChanged: viewModel.onPageChanged,
                              eventLoader: viewModel.getTasksForDay,
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) =>
                                    _buildCalendarDayCell(context, day, focusedDay),
                                todayBuilder: (context, day, focusedDay) =>
                                    _buildCalendarDayCell(context, day, focusedDay,
                                        isToday: true),
                                selectedBuilder: (context, day, focusedDay) =>
                                    _buildCalendarDayCell(context, day, focusedDay,
                                        isSelected: true),
                                outsideBuilder: (context, day, focusedDay) =>
                                    Opacity(
                                        opacity: 0.5,
                                        child: _buildCalendarDayCell(
                                            context, day, focusedDay,
                                            isOutside: true)),
                              ),
                              headerStyle: HeaderStyle(
                                titleTextStyle: const TextStyle(
                                  color: Color.fromARGB(255, 226, 226, 226),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                formatButtonVisible: false,
                                leftChevronIcon: const Icon(Icons.chevron_left,
                                    color: Color.fromARGB(255, 255, 255, 255)),
                                rightChevronIcon: const Icon(Icons.chevron_right,
                                    color: Color.fromARGB(255, 255, 255, 255)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSelectedDayTasks(context, viewModel),
                            const SizedBox(height: 16),
                            _buildAddNoteField(context, noteViewModel,
                                viewModel.currentActiveGoal),
                            _buildDailyNoteDisplay(context, noteViewModel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // **[NEW]** Top drag target for auto-scrolling up
                Align(
                  alignment: Alignment.topCenter,
                  child: DragTarget<TaskHiveModel>(
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        height: 50,
                        width: double.infinity,
                        color: Colors.transparent,
                      );
                    },
                    onMove: (details) {
                      if (_scrollTimer == null) {
                        _startScrolling(-10.0);
                      }
                    },
                    onLeave: (data) {
                      _stopScrolling();
                    },
                  ),
                ),
                // **[NEW]** Bottom drag target for auto-scrolling down
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DragTarget<TaskHiveModel>(
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        height: 50,
                        width: double.infinity,
                        color: Colors.transparent,
                      );
                    },
                    onMove: (details) {
                      if (_scrollTimer == null) {
                        _startScrolling(10.0);
                      }
                    },
                    onLeave: (data) {
                      _stopScrolling();
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GoalInputPage()));
          if (context.mounted) {
            context.read<AIFinanceViewModel>().loadInitialData();
          }
        },
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCalendarDayCell(
      BuildContext context, DateTime day, DateTime focusedDay,
      {bool isToday = false, bool isSelected = false, bool isOutside = false}) {
    final viewModel = context.read<AIFinanceViewModel>();
    return DragTarget<TaskHiveModel>(
      builder: (context, accepted, rejected) {
        bool isHovered = accepted.isNotEmpty;
        return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.blueAccent
                  : (isToday ? const Color(0xFF5A5A5A) : null),
              border: isHovered
                  ? Border.all(color: Colors.greenAccent, width: 2.5)
                  : null,
            ),
            child: Text('${day.day}',
                style: TextStyle(
                    color: isOutside
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white)));
      },
      onAcceptWithDetails: (details) =>
          viewModel.handleTaskDroppedOnCalendar(details.data, day),
    );
  }

  Widget _buildSelectedDayTasks(
      BuildContext context, AIFinanceViewModel viewModel) {
    if (viewModel.selectedDay == null) return const SizedBox.shrink();
    final tasks = viewModel.getTasksForDay(viewModel.selectedDay!);
    if (tasks.isEmpty)
      return const Center(
          child: Text('No tasks for this day.',
              style: TextStyle(color: Colors.white54, fontSize: 16)));

    return Column(
      children: tasks.map((task) {
        final taskCard = Card(
          color: const Color(0xFF2A2A2A),
          child: ListTile(
            title: Text(task.title,
                style: TextStyle(
                    color: Colors.white,
                    decoration: task.isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none)),
            trailing: Icon(
                task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: task.isDone ? Colors.greenAccent : Colors.white54),
            onTap: () => viewModel.toggleTaskCompletion(task),
          ),
        );

        return LongPressDraggable<TaskHiveModel>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 48),
              child: taskCard,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.5, child: taskCard),
          // **[NEW]** Stop scrolling when drag ends
          onDragEnd: (details) {
            _stopScrolling();
          },
          child: taskCard,
        );
      }).toList(),
    );
  }

  Widget _buildDraggableTasks(
      BuildContext context, AIFinanceViewModel viewModel) {
    final taskListView = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 162),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        scrollDirection: Axis.horizontal,
        itemCount: viewModel.draggableDailyTasks.length,
        itemBuilder: (context, index) {
          final task = viewModel.draggableDailyTasks[index];
          final taskWidget = Container(
              width: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF2D2D44),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Column(children: [
                Text(task.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Divider(),
                Text(task.purpose ?? 'no description',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.normal),
                    textAlign: TextAlign.start,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis)
              ])));
          return GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.black,
                builder: (ctx) => DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (_, scrollController) => SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          task.purpose ?? 'No description',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: LongPressDraggable<TaskHiveModel>(
              data: task,
              feedback: Material(color: Colors.transparent, child: taskWidget),
              childWhenDragging: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14))),
              // **[NEW]** Stop scrolling when drag ends
              onDragEnd: (details) {
                _stopScrolling();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: taskWidget,
              ),
            ),
          );
        },
      ),
    );

    return DragTarget<TaskHiveModel>(
      builder: (context, candidateData, rejectedData) {
        bool isHovered = candidateData.any((task) => task?.dueDate != null);
        return Container(
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.deepPurple.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: viewModel.draggableDailyTasks.isEmpty
              ? SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      Text("No tasks to schedule.",
                      maxLines: 2,
                          style: TextStyle(color: Colors.white54)
                        ),
                      SizedBox(width: 20,),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const PlanRoadmapScreen()));
                          if (context.mounted) {
                            context.read<AIFinanceViewModel>().loadInitialData();
                          }
                        },
                        child:Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          
                          gradient: LinearGradient(colors: [Colors.deepPurple, const Color.fromARGB(255, 148, 109, 255).withOpacity(0.85)])
                        ),
                        child: Center(
                          child: Icon(Icons.add, color: Colors.white,),
                        ),
                      ),)
                          ]))
              : taskListView,
        );
      },
      onAcceptWithDetails: (details) {
        if (details.data.dueDate != null) {
          viewModel.returnTaskToDraggableList(details.data);
        }
      },
    );
  }

  // ... (The rest of the file remains unchanged)
  Widget _buildAddNoteField(
      BuildContext context, NoteViewModel noteViewModel, TaskHiveModel? goal) {
    return GestureDetector(
      onTap: () {
        if (goal != null &&
            context.read<AIFinanceViewModel>().selectedDay != null) {
          _showAddNoteModal(context, noteViewModel,
              context.read<AIFinanceViewModel>().selectedDay!, goal.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.note_add_outlined, color: Colors.white70),
          SizedBox(width: 12),
          Text("Add a note for this day...",
              style: TextStyle(color: Colors.white70, fontSize: 16))
        ]),
      ),
    );
  }

  void _showAddNoteModal(BuildContext context, NoteViewModel noteViewModel,
      DateTime day, String goalId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                    controller: _noteController,
                    autofocus: true,
                    expands: true,
                    maxLines: null,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Your note...",
                        hintStyle: TextStyle(color: Colors.white54)))),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                child: const Text("Save Note"),
                onPressed: () {
                  noteViewModel.saveNote(_noteController.text, day, goalId);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyNoteDisplay(
      BuildContext context, NoteViewModel noteViewModel) {
    final note = noteViewModel.noteForSelectedDay;
    if (noteViewModel.isLoading)
      return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(child: CircularProgressIndicator()));
    if (note == null || note.content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Note for the day:",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text(note.content,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewPlanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          builder: (_, controller) => const PlanRoadmapScreen(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.deepPurple.withOpacity(0.85),
            const Color.fromARGB(255, 178, 151, 252).withOpacity(0.85)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(children: [
          Text("Review my plan",
              style: TextStyle(color: Colors.white, fontSize: 20)),
          Spacer(),
          Icon(Icons.flag, color: Colors.white),
          Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16)
        ]),
      ),
    );
  }
}