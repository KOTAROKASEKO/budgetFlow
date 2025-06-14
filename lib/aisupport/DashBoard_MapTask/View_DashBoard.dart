import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moneymanager/ads/ViewModel_ads.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/ViewModel_DashBoard.dart';
import 'package:moneymanager/aisupport/RoadMaps/View_roadMapRecord.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/goal_input/View_goalInput.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';


class FinancialGoalPage extends StatefulWidget {
  const FinancialGoalPage();
  @override
  State<FinancialGoalPage> createState() => _FinancialGoalViewState();
}

class _FinancialGoalViewState extends State<FinancialGoalPage> with SingleTickerProviderStateMixin {
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker; 
  String? _expandedTaskId;
  String adkey = 'View_DashBoard_Ad';

  @override
  void initState() {
    super.initState();
    final noteViewModel = context.read<NoteViewModel>();
    _noteController.text = noteViewModel.noteForSelectedDay?.content ?? '';
    noteViewModel.addListener(_onNoteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIFinanceViewModel>().onDaySelected(DateTime.now(), DateTime.now());
      Provider.of<AdViewModel>(context, listen: false).loadAd(adkey);
    });
  }

  void _onNoteChanged() {
    final noteViewModel = context.read<NoteViewModel>();
    if (_noteController.text !=
        (noteViewModel.noteForSelectedDay?.content ?? '')) {
      _noteController.text = noteViewModel.noteForSelectedDay?.content ?? '';
    }
  }

  void _startScrolling(double speed) {
    _stopScrolling(); // 既存のTickerを停止
    _ticker = createTicker((elapsed) {
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
    _ticker?.start();
  }

  void _stopScrolling() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }


  @override
  void dispose() {
    context.read<NoteViewModel>().removeListener(_onNoteChanged);
    _noteController.dispose();
     _ticker?.dispose();
    _scrollController.dispose();
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            Image.asset('assets/ai.png', width: 40, height: 40,),
            Text('Financial Goal',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
                ]),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: viewModel.isLoading && viewModel.currentActiveGoal == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      _buildAd(Provider.of<AdViewModel>(context), adkey),
                      _buildAvatar(context, viewModel),
                      // --- NEW: Streak Tracker Widget ---
                      _buildStreakTracker(context, viewModel),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                                  ? "Long-press a task to drag it to the calendar."
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
                              availableGestures: AvailableGestures.horizontalSwipe,
                              selectedDayPredicate: (day) =>
                                  isSameDay(viewModel.selectedDay, day),
                              onDaySelected: viewModel.onDaySelected,
                              onFormatChanged: (format) {},
                              onPageChanged: viewModel.onPageChanged,
                              eventLoader: viewModel.getTasksForDay,
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, day, events) {
                                  if (events.isNotEmpty) {
                                    return Positioned(
                                      right: 1,
                                      bottom: 1,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.deepPurpleAccent,
                                        ),
                                        width: 7.0,
                                        height: 7.0,
                                      ),
                                    );
                                  }
                                  return null;
                                },
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
                      if (_ticker == null) {
                        _startScrolling(-10.0);
                      }
                    },
                    onLeave: (data) {
                      _stopScrolling();
                    },
                  ),
                ),
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
                      if (_ticker == null) {
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
            
      floatingActionButton:viewModel.goalAvailability? FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GoalInputPage()));
          if (context.mounted) {
            context.read<AIFinanceViewModel>().loadInitialData();
          }
        },
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ):SizedBox(),
    
    );
  }

  // --- NEW: Streak Tracker Widget ---
  Widget _buildStreakTracker(BuildContext context, AIFinanceViewModel viewModel) {
    final streak = viewModel.streakData?.currentStreak ?? 0;
    final points = viewModel.streakData?.totalPoints ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.black.withOpacity(0.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CURRENT STREAK", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text("$streak DAYS", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("TOTAL POINTS", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text("$points PTS", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayNumber = index + 1;
              final isCompleted = dayNumber <= streak;
              // A simple logic to check if today's task is done to show a filled check
              bool isTodayCompleted = isCompleted && isSameDay(viewModel.streakData?.lastCompletionDate, DateTime.now());
              
              return Column(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    color: isCompleted ? (isTodayCompleted ? Colors.amberAccent : Colors.greenAccent) : Colors.white24,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text("Day $dayNumber", style: TextStyle(color: isCompleted ? Colors.white : Colors.white54, fontSize: 12)),
                ],
              );
            }),
          ),
        ],
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
    if (tasks.isEmpty) {
      return const Center(
          child: Text('No tasks for this day.',
              style: TextStyle(color: Colors.white54, fontSize: 16)));
    }

    // --- MODIFIED: check if the selected day is today ---
    final bool isToday = isSameDay(viewModel.selectedDay, DateTime.now());

    return Column(
      children: tasks.map((task) {
        final isExpanded = _expandedTaskId == task.id;
        
        final expandedContent = Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                "Purpose:",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                task.purpose ?? 'No purpose defined.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  // --- MODIFIED: Disable button if not today ---
                  onPressed: isToday ? () => viewModel.toggleTaskCompletion(task) : null,
                  icon: Icon(
                    task.isDone
                        ? Icons.close_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(task.isDone ? "Mark as Incomplete" : "Mark as Done"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.isDone
                        ? Colors.grey.shade600
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    // --- MODIFIED: Visual feedback for disabled button ---
                    disabledBackgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final taskCard = Material(
          color: const Color(0xFF2A2A2A),
          borderRadius: isExpanded
              ? const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                )
              : BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedTaskId = null;
                } else {
                  _expandedTaskId = task.id;
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    task.title,
                    style: TextStyle(
                      color: Colors.white,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: Colors.white54,
                    ),
                  ),
                  trailing: Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white54,
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: Container(),
                  secondChild: expandedContent,
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        );
        
        final draggableItem = LongPressDraggable<TaskHiveModel>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 48),
              child: Card(
                color: const Color(0xFF2A2A2A),
                child: ListTile(title: Text(task.title, style: const TextStyle(color: Colors.white))),
              )
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: taskCard
            )
          ),
          onDragEnd: (details) {
            _stopScrolling();
          },
          child: taskCard,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: draggableItem,
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
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color.fromARGB(130, 77, 32, 118),
                  ),
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(5),
                    child:Text(task.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),)),
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
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(children:[Padding(
              padding: const EdgeInsets.all(16.0),
              child: Expanded(
                child:TextField(
                  controller: _noteController,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 18),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Your note...",
                      hintStyle: TextStyle(color: Colors.white54))
                      )
                      )
                      ),]),
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
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            builder: (_, controller) => const PlanRoadmapScreen(isModal: true),
          ),
        );
        if (mounted) {
          context.read<AIFinanceViewModel>().loadInitialData();
        }
      },
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
  
  Widget _buildAvatar(BuildContext context, AIFinanceViewModel viewModel) {
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Image.network(
        viewModel.picUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200,
          height: 200,
          color: Colors.grey[800],
          child: const Icon(Icons.person, color: Colors.white, size: 100),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 200,
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        },
          ),
        ),
    ],);
  }
  
  Widget _buildAd(AdViewModel adViewModel, String adId) {
    // 1. isAdLoaded(adId) を使って、特定の広告のロード状態を確認します。
    if (adViewModel.isAdLoaded(adId)) {
      // 2. getAd(adId) を使って、特定の広告オブジェクトを取得します。
      final bannerAd = adViewModel.getAd(adId);

      // 広告がnullでないことを確認してから表示します。
      if (bannerAd != null) {
        return Container(
          alignment: Alignment.center,
          child: AdWidget(ad: bannerAd),
          width: bannerAd.size.width.toDouble(),
          height: bannerAd.size.height.toDouble(),
        );
      } else {
        // 予期せず広告がnullだった場合の表示
        return Container(
          height: 50.0,
          alignment: Alignment.center,
          child: Text('Ad data not found.'),
        );
      }
    } else {
      // ロード中、またはロードに失敗した場合の表示
      return Container(
        height: 50.0, // バナー広告と同じ高さ
        alignment: Alignment.center,
        child: Text('Ad is loading...'),
      );
    }
  }
}