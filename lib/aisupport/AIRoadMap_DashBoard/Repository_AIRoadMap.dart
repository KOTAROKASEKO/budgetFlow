import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/ViewModel_AIRoadMap.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/View_AIRoadMap.dart';
import 'package:moneymanager/aisupport/RoadMaps/View_roadMapRecord.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:moneymanager/aisupport/Goal_input/goal_input/goalInput.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/notes/note_repository.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/notes/note_veiwmodel.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class FinancialGoalPage extends StatelessWidget {
  const FinancialGoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The providers are now responsible for creating the ViewModel and Repository
    return MultiProvider(
      providers: [
        Provider(create: (context) => NoteRepository()),
        ChangeNotifierProvider(
          create: (context) => NoteViewModel(
            noteRepository: context.read<NoteRepository>(),
          ),
        ),
        Provider(
          create: (context) => AIFinanceRepository(
            localPlanRepository: context.read<PlanRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AIFinanceViewModel(
            repository: context.read<AIFinanceRepository>(),
            noteViewModel: context.read<NoteViewModel>(),
          ),
        ),
      ],
      child: const _FinancialGoalView(),
    );
  }
}

class _FinancialGoalView extends StatefulWidget {
  const _FinancialGoalView();

  @override
  State<_FinancialGoalView> createState() => _FinancialGoalViewState();
}

class _FinancialGoalViewState extends State<_FinancialGoalView> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listen to the NoteViewModel to update the text controller
    final noteViewModel = context.read<NoteViewModel>();
    _noteController.text = noteViewModel.noteForSelectedDay?.content ?? '';
    noteViewModel.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    final noteViewModel = context.read<NoteViewModel>();
    if (_noteController.text != (noteViewModel.noteForSelectedDay?.content ?? '')) {
      _noteController.text = noteViewModel.noteForSelectedDay?.content ?? '';
    }
  }

  @override
  void dispose() {
    context.read<NoteViewModel>().removeListener(_onNoteChanged);
    _noteController.dispose();
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
        title: const Text('Financial Goal', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: viewModel.isLoading && viewModel.currentActiveGoal == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ListView(
                  children: [
                    Text(
                      viewModel.currentActiveGoal?.title ?? "No Goal Set",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 20, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 8),
                    _buildDraggableTasks(context, viewModel),
                    const SizedBox(height: 24),
                    _buildReviewPlanButton(context),
                    TableCalendar<TaskHiveModel>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: viewModel.focusedDay,
                      calendarFormat: viewModel.calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(viewModel.selectedDay, day),
                      onDaySelected: viewModel.onDaySelected,
                      onFormatChanged: viewModel.onFormatChanged,
                      onPageChanged: viewModel.onPageChanged,
                      eventLoader: viewModel.getTasksForDay,
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) => _buildCalendarDayCell(context, day, focusedDay),
                        todayBuilder: (context, day, focusedDay) => _buildCalendarDayCell(context, day, focusedDay, isToday: true),
                        selectedBuilder: (context, day, focusedDay) => _buildCalendarDayCell(context, day, focusedDay, isSelected: true),
                        outsideBuilder: (context, day, focusedDay) => Opacity(opacity: 0.5, child: _buildCalendarDayCell(context, day, focusedDay, isOutside: true)),
                      ),
                      // ... (CalendarStyle, HeaderStyle, DaysOfWeekStyle)
                    ),
                    const SizedBox(height: 16),
                    _buildSelectedDayTasks(context, viewModel),
                    const SizedBox(height: 16),
                    _buildAddNoteField(context, noteViewModel, viewModel.currentActiveGoal),
                    _buildDailyNoteDisplay(context, noteViewModel),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GoalInputPage()));
          context.read<AIFinanceViewModel>().loadInitialData();
        },
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCalendarDayCell(BuildContext context, DateTime day, DateTime focusedDay, {bool isToday = false, bool isSelected = false, bool isOutside = false}) {
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
              color: isSelected ? Colors.blueAccent : (isToday ? const Color(0xFF5A5A5A) : null),
              border: isHovered ? Border.all(color: Colors.greenAccent, width: 2.5) : null,
            ),
            child: Text('${day.day}', style: TextStyle(color: isOutside ? Colors.white.withOpacity(0.4) : Colors.white)));
      },
      onAcceptWithDetails: (details) => viewModel.handleTaskDroppedOnCalendar(details.data, day),
    );
  }

  Widget _buildSelectedDayTasks(BuildContext context, AIFinanceViewModel viewModel) {
    if (viewModel.selectedDay == null) return const SizedBox.shrink();
    final tasks = viewModel.getTasksForDay(viewModel.selectedDay!);
    if (tasks.isEmpty) return const Center(child: Text('No tasks for this day.', style: TextStyle(color: Colors.white54, fontSize: 16)));

    return Column(
      children: tasks.map((task) => Card(
        color: const Color(0xFF2A2A2A),
        child: ListTile(
          title: Text(task.title, style: TextStyle(color: Colors.white, decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none)),
          trailing: Icon(task.isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: task.isDone ? Colors.greenAccent : Colors.white54),
          onTap: () => viewModel.toggleTaskCompletion(task),
        ),
      )).toList(),
    );
  }

  Widget _buildDraggableTasks(BuildContext context, AIFinanceViewModel viewModel) {
    if (viewModel.draggableDailyTasks.isEmpty) return const SizedBox(height: 134, child: Center(child: Text("No tasks to schedule.", style: TextStyle(color: Colors.white54))));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 162),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: viewModel.draggableDailyTasks.length,
        itemBuilder: (context, index) {
          final task = viewModel.draggableDailyTasks[index];
          final taskWidget = Container(width: 140, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF2D2D44), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(task.title, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis)));
          return LongPressDraggable<TaskHiveModel>(
            data: task,
            feedback: Material(color: Colors.transparent, child: taskWidget),
            childWhenDragging: Container(width: 140, margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(14))),
            child: Padding(padding: const EdgeInsets.all(8.0), child: taskWidget),
          );
        },
      ),
    );
  }
  
  Widget _buildAddNoteField(BuildContext context, NoteViewModel noteViewModel, TaskHiveModel? goal) {
    return GestureDetector(
      onTap: () {
        if (goal != null && context.read<AIFinanceViewModel>().selectedDay != null) {
          _showAddNoteModal(context, noteViewModel, context.read<AIFinanceViewModel>().selectedDay!, goal.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [Icon(Icons.note_add_outlined, color: Colors.white70), SizedBox(width: 12), Text("Add a note for this day...", style: TextStyle(color: Colors.white70, fontSize: 16))]),
      ),
    );
  }

  void _showAddNoteModal(BuildContext context, NoteViewModel noteViewModel, DateTime day, String goalId) {
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
            body: Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: _noteController, autofocus: true, expands: true, maxLines: null, style: const TextStyle(color: Colors.white, fontSize: 18), decoration: const InputDecoration(border: InputBorder.none, hintText: "Your note...", hintStyle: TextStyle(color: Colors.white54)))),
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

  Widget _buildDailyNoteDisplay(BuildContext context, NoteViewModel noteViewModel) {
    final note = noteViewModel.noteForSelectedDay;
    if (noteViewModel.isLoading) return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()));
    if (note == null || note.content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Note for the day:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(note.content, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          builder: (_, controller) => const PlanRoadmapScreen(), // Assuming this screen is provided correctly
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.deepPurple.withOpacity(0.85), Colors.deepPurpleAccent.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(children: [Text("Review my plan", style: TextStyle(color: Colors.white, fontSize: 20)), Spacer(), Icon(Icons.flag, color: Colors.white), Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16)]),
      ),
    );
  }
}