// lib/aisupport/DashBoard_MapTask/View_DashBoard.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moneymanager/ads/ViewModel_ads.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/NoteView.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/ViewModel_DashBoard.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/model/note_hive_model.dart';
import 'package:moneymanager/aisupport/RoadMaps/View_roadMapRecord.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/goal_input/View_goalInput.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/feedback/feedback.dart';
import 'package:moneymanager/notification_service/notification_service.dart';
import 'package:moneymanager/security/Authentication.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

// --- NEW HELPER METHOD: To show the modal sheet ---
// This avoids code duplication
void _showTaskDetailModal(BuildContext context, TaskHiveModel task) {
  // Ensure the ViewModel is available
  final viewModel = context.read<AIFinanceViewModel>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Make it transparent to use custom decoration
    builder: (ctx) => TaskDetailModal(task: task, viewModel: viewModel),
  );
}

class FinancialGoalPage extends StatefulWidget {
  const FinancialGoalPage({super.key});
  @override
  State<FinancialGoalPage> createState() => _FinancialGoalViewState();
}

class _FinancialGoalViewState extends State<FinancialGoalPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker;
  double _scrollSpeed = 0.0; // スクロール速度を管理する変数
  // --- REMOVED: No longer needed as we use a modal sheet ---
  // String? _expandedTaskId; 
  String adkey = 'View_DashBoard_Ad';

  @override
  void initState() {
    super.initState();
        _ticker = createTicker((elapsed) {
      if (_scrollSpeed == 0.0) return; // 速度が0なら何もしない

      final newOffset = _scrollController.offset + _scrollSpeed;
      if (newOffset <= _scrollController.position.minScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        _scrollSpeed = 0.0; // 端に達したら停止
      } else if (newOffset >= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _scrollSpeed = 0.0; // 端に達したら停止
      } else {
        _scrollController.jumpTo(newOffset);
      }
    });
    _ticker?.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<AIFinanceViewModel>()
          .onDaySelected(DateTime.now(), DateTime.now());
      Provider.of<AdViewModel>(context, listen: false).loadAd(adkey);
    });
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => UserAuthScreen()), 
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      print('Failed to sign out: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: ${e.message ?? "Unknown error"}'), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      print('An unexpected error occurred during sign out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred. Please try again.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AIFinanceViewModel>();
    final noteViewModel = context.watch<NoteViewModel>();

    return Stack(
      children: [
        if (viewModel.showCelebration)
        Positioned.fill(
          child: Image.asset(
            'assets/fireworks.gif', 
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      Scaffold(

      backgroundColor: const Color.fromARGB(126, 70, 70, 70),
      drawer:Drawer(
          backgroundColor: const Color(0xFF1A1A1A),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  decoration: BoxDecoration(color: theme.apptheme_Black.withOpacity(0.15)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.apptheme_Black,
                        child: const Icon(Icons.account_balance_wallet_rounded, size: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text("Finance Planner", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text("Version 1.7.0", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8.0),
                    children: [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.exit_to_app_outlined,
                        text: 'Sign Out',
                        accentColor: theme.apptheme_Black,
                        onTap: () async {
                          Navigator.pop(context);
                          await signOut(context);
                        },
                      ),
                      const Divider(color: Colors.white12, indent: 20, endIndent: 20, height: 1),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.feedback_outlined,
                        text: 'Send Feedback',
                        accentColor: theme.apptheme_Black,
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))),
                            builder: (BuildContext modalContext) => FeedbackForm(),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.info_outline_rounded,
                        text: 'About Us',
                        accentColor: theme.apptheme_Black,
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                              context: context,
                              builder: (context) => AboutDialog(
                                    applicationName: 'Finance Planner',
                                    applicationVersion: '1.7.3',
                                    applicationIcon: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: theme.apptheme_Black,
                                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                                    ),
                                    applicationLegalese: '© ${DateTime.now().year} kotaro.sdn.bhd',
                                    children: <Widget>[
                                      const SizedBox(height: 15),
                                      const Text('This app helps you manage your finances efficiently.'),
                                    ],
                                  ));
                        },
                      ),
                      const Divider(color: Colors.white12, indent: 20, endIndent: 20, height: 1),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
                  child: Text(
                    "Your finances, simplified.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
     
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        centerTitle: true,
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset(
            'assets/ai.png',
            width: 40,
            height: 40,
          ),
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
                      _buildStreakTracker(context, viewModel),
                       _buildTodaysTasksSimplified(context, viewModel),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                             Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      viewModel.currentActiveGoal?.title != null && viewModel.currentActiveGoal!.title.isNotEmpty
                                        ? "${viewModel.currentActiveGoal!.title}'s DailyTasks"
                                        : "No Goal Set",
                                    maxLines: 1, // 1行に制限
                                    overflow: TextOverflow.ellipsis, // はみ出た部分を...で表示
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.start,
                                  ),
                                  const SizedBox(height: 8),
                                  if (viewModel.currentActiveGoal?.title.isNotEmpty == true)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.deepPurple),
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color.fromARGB(157, 104, 58, 183)
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                        child: Text(
                                          "Drag -> allocate on day",
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // --- NEW: Add Task Button ---
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.deepPurpleAccent, size: 32),
                              onPressed: () {
                                if (viewModel.currentActiveGoal != null) {
                                    showModalBottomSheet(
                                    enableDrag: true,
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => DraggableScrollableSheet(
                                      
                                      initialChildSize: 0.7,
                                      minChildSize: 0.4,
                                      maxChildSize: 0.95,
                                      expand: false,
                                      builder: (_, scrollController) => AddTaskModal(
                                        viewModel: viewModel,
                                        parentGoal: viewModel.currentActiveGoal!,
                                      ),
                                    ),
                                    );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please create a main goal first.")),
                                  );
                                }
                              },
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
                              availableGestures:
                                  AvailableGestures.horizontalSwipe,
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
                                    _buildCalendarDayCell(
                                        context, day, focusedDay),
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
                                rightChevronIcon: const Icon(
                                    Icons.chevron_right,
                                    color: Color.fromARGB(255, 255, 255, 255)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // --- MODIFIED: This now uses a simple tap to open the modal ---
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
                      _scrollSpeed = -10.0; // 上方向のスクロール速度を設定
                    },
                    onLeave: (data) {
                      _scrollSpeed = 0.0; // 領域から離れたら停止
                    },
                  ),
                ),
                // --- MODIFIED: 下部のDragTargetのロジックを簡素化 ---
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
                      _scrollSpeed = 10.0; // 下方向のスクロール速度を設定
                    },
                    onLeave: (data) {
                      _scrollSpeed = 0.0; // 領域から離れたら停止
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: viewModel.goalAvailability
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const GoalInputPage()));
                if (context.mounted) {
                  context.read<AIFinanceViewModel>().loadInitialData();
                }
              },
              backgroundColor: Colors.deepPurpleAccent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : SizedBox(),
          
    ),
       
    ]);
  }

  Widget _buildTodaysTasksSimplified(BuildContext context, AIFinanceViewModel viewModel) {
    final today = DateTime.now();
    final tasks = viewModel.getTasksForDay(today);

    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            "You have no tasks for today. Enjoy your day!",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(154, 75, 75, 75),
        borderRadius: BorderRadius.circular(20)
      ),
      child:Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            "Today's Tasks",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
         Padding(
          padding: const EdgeInsets.fromLTRB(24.0,0,24,24),
          child: Column(
            children: tasks.map((task) {
              return Card(
                color: const Color(0xFF2A2A2A),
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  title: Text(
                    task.title,
                    style: TextStyle(
                      color: Colors.white,
                      decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: Colors.white54
                    ),
                  ),
                  trailing: Icon(
                    task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: task.isDone ? Colors.greenAccent : Colors.white54,
                  ),
                  onTap: () => _showTaskDetailModal(context, task),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ));
  }

  Widget _buildStreakTracker(
      BuildContext context, AIFinanceViewModel viewModel) {
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
                  const Text("CURRENT STREAK",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text("$streak DAYS",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("TOTAL POINTS",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text("$points PTS",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
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
              bool isTodayCompleted = isCompleted &&
                  isSameDay(
                      viewModel.streakData?.lastCompletionDate, DateTime.now());

              return Column(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: isCompleted
                        ? (isTodayCompleted
                            ? Colors.amberAccent
                            : Colors.greenAccent)
                        : Colors.white24,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text("Day $dayNumber",
                      style: TextStyle(
                          color: isCompleted ? Colors.white : Colors.white54,
                          fontSize: 12)),
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

  Widget _buildAvatar(BuildContext context, AIFinanceViewModel viewModel) {
      return Column( 
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
          const SizedBox(height: 16),
          if (viewModel.streakMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                viewModel.streakMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'robot',
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 16,)
        ],
      );
    }

  Widget _buildAd(AdViewModel adViewModel, String adId) {
    if (adViewModel.isAdLoaded(adId)) {
      final bannerAd = adViewModel.getAd(adId);
      if (bannerAd != null) {
        return Container(
          alignment: Alignment.center,
          width: bannerAd.size.width.toDouble(),
          height: bannerAd.size.height.toDouble(),
          child: AdWidget(ad: bannerAd),
        );
      } else {
        return Container(
          height: 50.0,
          alignment: Alignment.center,
          child: Text('Ad data not found.'),
        );
      }
    } else {
      return Container(
        height: 50.0,
        alignment: Alignment.center,
        child: Text('Ad is loading...'),
      );
    }
  }
  
  Widget _buildDrawerItem({required BuildContext context, required IconData icon, required String text, required GestureTapCallback onTap, required Color accentColor}) {
    return ListTile(
      leading: Icon(icon, color: theme.foregroundColor, size: 24),
      title: Text(text, style: TextStyle(fontSize: 15.5, color: Colors.white.withOpacity(0.87), fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 12.0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: Colors.white.withOpacity(0.05),
      splashColor: accentColor.withOpacity(0.1),
    );
  }

  // --- REFACTORED: To use modal bottom sheet ---
  Widget _buildSelectedDayTasks(
      BuildContext context, AIFinanceViewModel viewModel) {
    if (viewModel.selectedDay == null) return const SizedBox.shrink();
    final tasks = viewModel.getTasksForDay(viewModel.selectedDay!);
    if (tasks.isEmpty) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('No tasks for this day.',
                style: TextStyle(color: Colors.white54, fontSize: 16)
                ),
          )
            );
    }

    return Column(
      children: tasks.map((task) {
        final taskCard = Material(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
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
              task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.isDone ? Colors.greenAccent : Colors.white54,
            ),
            onTap: () => _showTaskDetailModal(context, task),
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: LongPressDraggable<TaskHiveModel>(
            data: task,
            feedback: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 48),
                  child: Card(
                    color: const Color(0xFF2A2A2A),
                    child: ListTile(
                        title: Text(task.title,
                            style: const TextStyle(color: Colors.white))),
                  )),
            ),
            childWhenDragging: Opacity(
                opacity: 0.5,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: taskCard)),
            onDragEnd: (details) {
                _scrollSpeed = 0.0;
              },  
            child: taskCard,
          ),
        );
      }).toList(),
    );
  }

  // --- REFACTORED: To use modal bottom sheet ---
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
                border: Border.all(
                  color: Colors.deepPurple,
                  width: 1.0,
                ),
                  color: const Color.fromARGB(255, 45, 45, 68),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Column(
                    children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color.fromARGB(130, 77, 32, 118),
                  ),
                  child: Padding(
                      padding: EdgeInsets.all(5),
                      child: Text(
                        task.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.start,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
                ),
                const Divider(),
                Text(task.purpose ?? 'no description',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.normal),
                    textAlign: TextAlign.start,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis)
              ])));

          return GestureDetector(
            onTap: () => _showTaskDetailModal(context, task),
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
              _scrollSpeed = 0.0;
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
                      children: [
                        Text("No tasks to schedule.",
                            maxLines: 2,
                            style: TextStyle(color: Colors.white54)),
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
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  NoteEditorScreen(
                noteViewModel: noteViewModel,
                day: context.read<AIFinanceViewModel>().selectedDay!,
                goalId: goal.id,
                initialContent: null,
                noteId: null,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeOut;
                final tween =
                    Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            ),
          );
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
          Text("Add a new note for this day...",
              style: TextStyle(color: Colors.white70, fontSize: 16))
        ]),
      ),
    );
  }
  
  Widget _buildDailyNoteDisplay(
    BuildContext context, NoteViewModel noteViewModel) {
  if (noteViewModel.isLoading) {
    return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()));
  }
  final notes = noteViewModel.notesForSelectedDay;
  if (notes.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 16.0),
    child: ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return GestureDetector(
          onLongPress: () {
            _showNoteOptions(context, noteViewModel, note);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Note ${index + 1}:",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(note.content,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        );
      },
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

  void _showNoteOptions(
    BuildContext context, NoteViewModel noteViewModel, NoteHiveModel note) {
  final aiViewModel = context.read<AIFinanceViewModel>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF222222),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(modalContext); 
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        noteViewModel: noteViewModel,
                        day: aiViewModel.selectedDay!,
                        goalId: note.goalId,
                        initialContent: note.content,
                        noteId: note.id,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(modalContext); 
                  await noteViewModel.deleteNote(
                    noteId: note.id,
                    day: aiViewModel.selectedDay!,
                    goalId: note.goalId,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
}

// --- NEW WIDGET: Reusable Modal Bottom Sheet for Task Details ---
class TaskDetailModal extends StatefulWidget {
  final TaskHiveModel task;
  final AIFinanceViewModel viewModel;

  const TaskDetailModal({
    super.key,
    required this.task,
    required this.viewModel,
  });

  @override
  State<TaskDetailModal> createState() => _TaskDetailModalState();
}


class _TaskDetailModalState extends State<TaskDetailModal> {
  late bool _sendNotification;
  late TimeOfDay _notificationTime;

  @override
  void initState() {
    super.initState();
    _sendNotification = widget.task.notificationTime != null;
    if (_sendNotification) {
      _notificationTime = TimeOfDay.fromDateTime(widget.task.notificationTime!);
    } else {
      // Default time if none is set
      _notificationTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF2A2A2A),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A1A1A)),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime != null && pickedTime != _notificationTime) {
      setState(() {
        _notificationTime = pickedTime;
      });
      // Automatically save the new time
      _confirmNotificationChanges();
    }
  }

    Future<void> _confirmNotificationChanges() async {
    DateTime? finalNotificationDateTime;
    if (_sendNotification) {
      // --- NEW: パーミッションチェックを追加 ---
      final bool hasPermission = await NotificationService().requestPermissions();
      if (!mounted) return;

      if (!hasPermission) {
        // 許可されなかった場合、ユーザーに通知し、スイッチをオフに戻す
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission is required for reminders.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _sendNotification = false; 
        });
        return; // 処理を中断
      }
      // ------------------------------------

      final date = widget.task.dueDate ?? DateTime.now();
      finalNotificationDateTime = DateTime(date.year, date.month, date.day, _notificationTime.hour, _notificationTime.minute);
    }
    
    // 許可がある場合のみ、通知設定/解除のロジックが実行される
    await widget.viewModel.setTaskNotification(widget.task, finalNotificationDateTime);

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_sendNotification ? 'Reminder set for ${_notificationTime.format(context)}' : 'Reminder cancelled.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  void _deleteTask() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this task and all its subtasks?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Close modal sheet
              widget.viewModel.deleteTask(widget.task.id);
            },
          ),
        ],
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    bool isTaskForToday = widget.task.dueDate != null && isSameDay(widget.task.dueDate!, DateTime.now());
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.task.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Purpose
                Text(
                  widget.task.purpose ?? 'No description provided.',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 24),
                
                // Sub-steps Checklist
                if (widget.task.subSteps != null && widget.task.subSteps!.isNotEmpty) ...[
                  const Text('Checklist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white38, height: 16),
                  ...widget.task.subSteps!.map((step) {
                    bool isDone = step['isDone'] ?? false;
                    String text = step['text'] ?? '';

                    return InkWell( // GestureDetectorからInkWellに変更してフィードバックを良くする
                      onTap: () {
                        setState(() {
                          step['isDone'] = !isDone;
                        });
                        // 変更をHiveに即時保存
                        widget.viewModel.updateTask(widget.task);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Icon(
                                isDone ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 22,
                                color: isDone ? Colors.deepPurpleAccent : Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isDone ? Colors.white54 : Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                  decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                const Text('Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white38, height: 16),
                
                // Mark as Done / Incomplete
                if(widget.task.dueDate != null) // Only show for scheduled tasks
                  ListTile(
                    leading: Icon(widget.task.isDone ? Icons.check_circle : Icons.check_circle_outline, color: widget.task.isDone ? Colors.greenAccent : Colors.white),
                    title: Text(widget.task.isDone ? 'Mark as Incomplete' : 'Mark as Done', style: TextStyle(color: Colors.white)),
                    onTap: () {
                       if(isTaskForToday){
                         widget.viewModel.toggleTaskCompletion(widget.task);
                         Navigator.pop(context);
                       } else {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You can only complete tasks scheduled for today.")));
                       }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                
                // Set Notification
                if(widget.task.dueDate != null) // Only show for scheduled tasks
                  SwitchListTile(
                    title: Text("Set Reminder", style: TextStyle(color: Colors.white)),
                    value: _sendNotification,
                    onChanged: (bool value) {
                      setState(() {
                        _sendNotification = value;
                      });
                      _confirmNotificationChanges();
                    },
                    inactiveThumbColor: Colors.deepPurpleAccent,
                    activeTrackColor: Colors.deepPurpleAccent,
                    secondary: Icon(Icons.notifications_outlined, color: const Color.fromARGB(255, 255, 255, 255)),
                    activeColor: const Color.fromARGB(255, 255, 255, 255),
                    contentPadding: EdgeInsets.zero,
                  ),
                if(_sendNotification && widget.task.dueDate != null)
                   ListTile(
                    title: Text('Reminder time: ${_notificationTime.format(context)}', style: TextStyle(color: Colors.white70)),
                    trailing: Icon(Icons.edit, color: Colors.white70),
                    onTap: _pickTime,
                    contentPadding: EdgeInsets.only(left: 55),
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
                  onTap: _deleteTask,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddTaskModal extends StatefulWidget {
  final AIFinanceViewModel viewModel;
  final TaskHiveModel parentGoal;

  const AddTaskModal({super.key, required this.viewModel, required this.parentGoal});

  @override
  State<AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<AddTaskModal> {
  final _titleController = TextEditingController();
  final _purposeController = TextEditingController();
  final List<TextEditingController> _subStepControllers = [TextEditingController()];

  @override
  void dispose() {
    _titleController.dispose();
    _purposeController.dispose();
    for (var controller in _subStepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title is required."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final newTask = TaskHiveModel(
      title: _titleController.text.trim(),
      purpose: _purposeController.text.trim().isNotEmpty ? _purposeController.text.trim() : null,
      subSteps: _subStepControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .map((text) => {'text': text, 'isDone': false})
          .toList(),
      taskLevel: TaskLevelName.Daily,
      duration: '1 day', // Manual daily tasks
      order: widget.viewModel.draggableDailyTasks.length, // Add to the end
      parentTaskId: widget.parentGoal.id,
      goalId: widget.parentGoal.id,
    );

    widget.viewModel.addManualTask(newTask);
    Navigator.pop(context);
  }
  
  void _addStepField() {
    setState(() {
      _subStepControllers.add(TextEditingController());
    });
  }

  void _removeStepField(int index) {
    setState(() {
      _subStepControllers[index].dispose();
      _subStepControllers.removeAt(index);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a New Daily Task', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  fillColor: Colors.black,
                  labelText: 'Task Title*', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _purposeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  fillColor: Colors.black,
                  labelText: 'Purpose (Optional)', labelStyle: TextStyle(color: Colors.white70)),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              const Text('Sub-steps (Optional)', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              ..._subStepControllers.asMap().entries.map((entry) {
                 int index = entry.key;
                 TextEditingController controller = entry.value;
                 return Row(
                   children: [
                     Expanded(
                       child: TextField(
                         controller: controller,
                         style: const TextStyle(color: Colors.white70),
                         decoration: InputDecoration(
                          labelStyle: TextStyle(color: const Color.fromARGB(255, 168, 168, 168)),
                          fillColor: Colors.black,
                          labelText: 'Step ${index + 1}'
                          ),
                       ),
                     ),
                     IconButton(
                       icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                       onPressed: () => _removeStepField(index),
                     )
                   ],
                 );
              }),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Step'),
                onPressed: _addStepField,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  child: const Text('Save Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}