// File: lib/aisupport/ui/plan_roadmap_screen.dart
import 'package:flutter/material.dart';
// --- NEW: Import the google_mobile_ads package ---
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moneymanager/ads/ViewModel_ads.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_DashBoard.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/ViewModel_DashBoard.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/View_PlanCreation.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart';
import 'package:moneymanager/aisupport/Goal_input/goal_input/View_goalInput.dart';
import 'package:moneymanager/aisupport/RoadMaps/ViewModel_Roadmap.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:provider/provider.dart';


class PlanRoadmapScreen extends StatefulWidget {
  final bool isModal;
  const PlanRoadmapScreen({super.key, this.isModal = false});

  @override
  State<PlanRoadmapScreen> createState() => _PlanRoadmapScreenState();
}

class _PlanRoadmapScreenState extends State<PlanRoadmapScreen> {
  late final RoadmapViewModel _viewModel;
  String adKey = 'View_roadMapRecord';
  @override
  void initState() {
    super.initState();
    _viewModel = RoadmapViewModel(
      repository:  Provider.of<AIFinanceRepository>(context, listen: false),
    );
    // --- NEW: Load the ad when the screen initializes ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdViewModel>(context, listen: false).loadAd(adKey);
      });
  }

  @override
  void dispose() {
    _viewModel.dispose();
   
    super.dispose();
  }
  
  // --- NEW: Method to load the banner ad ---
  
  void _showItemOptionsMenu(
    BuildContext context,
    RoadmapViewModel viewModel,
    TaskHiveModel taskItem,
    Offset globalPosition,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPosition.dx, globalPosition.dy, MediaQuery.of(context).size.width - globalPosition.dx, MediaQuery.of(context).size.height - globalPosition.dy),
      items: [
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit Title'))),
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Delete Plan'))),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'edit':
          _showEditDialog(context, viewModel, taskItem);
          break;
        case 'delete':
          _showDeleteConfirmDialog(context, viewModel, taskItem);
          break;
      }
    });
  }

  Future<void> _showEditDialog(BuildContext context, RoadmapViewModel viewModel, TaskHiveModel task) async {
    final titleController = TextEditingController(text: task.title);
    final purposeController = TextEditingController(text: task.purpose ?? '');
    final durationController = TextEditingController(text: task.duration);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF23232B),
      title: Row(
        children: [
        const Icon(Icons.edit, color: Colors.deepPurpleAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
          'Edit ${task.title}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          ),
        ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
          controller: titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Title',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.deepPurple.shade900.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent),
            ),
          ),
          ),
          const SizedBox(height: 12),
          TextField(
          controller: purposeController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Purpose',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.deepPurple.shade900.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent),
            ),
          ),
          ),
          const SizedBox(height: 12),
          TextField(
          controller: durationController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Estimated Duration',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.deepPurple.shade900.withOpacity(0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent),
            ),
          ),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
        onPressed: () => Navigator.of(ctx).pop(),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
        child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
        icon: const Icon(Icons.save, size: 18),
        label: const Text('Save'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.of(ctx).pop({
          'title': titleController.text,
          'purpose': purposeController.text,
          'duration': durationController.text,
          });
        },
        ),
      ],
      ),
    );

    if (result != null) {
      await viewModel.editTask(task, result['title']!, result['purpose'], result['duration']!);
        if (context.mounted && viewModel.errorMessage == null) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("'${task.title}' updated."), backgroundColor: Colors.green),
            );
        } else if (context.mounted && viewModel.errorMessage != null){
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Update failed: ${viewModel.errorMessage}"), backgroundColor: Colors.red),
            );
        }
    }
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context, RoadmapViewModel viewModel, TaskHiveModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${task.title}?'),
        content: Text('Are you sure you want to delete "${task.title}"${task.taskLevel == TaskLevelName.Goal ? " and all its sub-tasks" : ""}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.deleteTask(task);
       if (context.mounted && viewModel.errorMessage == null) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("'${task.title}' deleted."), backgroundColor: Colors.green),
            );
        } else if (context.mounted && viewModel.errorMessage != null){
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Delete failed: ${viewModel.errorMessage}"), backgroundColor: Colors.red),
            );
        }
    }
  }

  Widget _buildGoalView(BuildContext context, RoadmapViewModel viewModel) {
    if (viewModel.goalTasks.isEmpty && !viewModel.isLoading) {
      return Center(
          child: Text(
              viewModel.errorMessage ?? "No financial plans set up yet. Create one with the AI planner!",
              style: const TextStyle(color: Colors.white54, fontSize: 16)));
    }
    
    if (viewModel.goalTasks.isEmpty) {
        return Container();
    }

    final goalTask = viewModel.goalTasks.first;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GestureDetector(
            onLongPressStart: (details) {
              _showItemOptionsMenu(context, viewModel, goalTask, details.globalPosition);
            },
            child: Card(
              color: Colors.deepPurple,
              elevation: 4,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ChangeNotifierProvider(
                        create: (_) => PlanCreationViewModel(
                          repository: Provider.of<AIFinanceRepository>(context, listen: false),
                          existingPlanRootTask: goalTask, 
                          initialEarnThisYear: goalTask.userInputEarnTarget ?? '', 
                          initialCurrentSkill: goalTask.userInputCurrentSkill ?? '', 
                          initialPreferToEarnMoney: goalTask.userInputPreferToEarnMoney ?? '', 
                          initialNote: goalTask.userInputNote ?? '',
                        ),
                        child: const PlanCreationScreen(),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 150),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            goalTask.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "View & Refine Roadmap ->",
                            style: TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // --- MODIFIED: Display the loaded ad ---
          _buildAd(Provider.of<AdViewModel>(context), adKey),
        ],
      ),
    );
  }

   Widget _buildItemsList(BuildContext context, RoadmapViewModel viewModel) {
    if (viewModel.currentLevelItems.isEmpty && !viewModel.isLoading) {
      return Center(child: Text(viewModel.errorMessage ?? "No items at this level.", style: const TextStyle(color: Colors.white54, fontSize: 16)));
    }
    return ListView.builder(
      itemCount: viewModel.currentLevelItems.length,
      itemBuilder: (context, index) {
        final item = viewModel.currentLevelItems[index];
        return _buildItemCard(context, viewModel, item);
      },
    );
  }

  Widget _buildItemCard(BuildContext context, RoadmapViewModel viewModel, TaskHiveModel item) {
    bool isMilestone = item.taskLevel == TaskLevelName.Milestone;

    return Card(
      color: Colors.deepPurple.shade400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: !isMilestone ? () => viewModel.navigateToTaskChildren(item) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (!isMilestone) const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
          // NEW: Display the Definition of Done checklist for milestones
          if (isMilestone && item.definitionOfDone != null && item.definitionOfDone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: item.definitionOfDone!.map((goal) {
                  return CheckboxListTile(
                    title: Text(goal['text'], style: TextStyle(color: Colors.white, decoration: goal['isDone'] ? TextDecoration.lineThrough : null)),
                    value: goal['isDone'],
                    onChanged: (bool? value) {
                      // TODO : Implement the toggle logic for milestone goals
                      viewModel.toggleMilestoneGoalCompletion(item, goal['text']);
                    },
                    activeColor: Colors.greenAccent,
                    checkColor: Colors.black,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          if (isMilestone) _buildStartMilestoneButton(context, item),
        ],
      ),
    );
  }



  Widget _buildScaffold(BuildContext context, RoadmapViewModel viewModel) {
    final mainContent = Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 81, 81, 81),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
          ),
        ),
        title: Text(
          viewModel.navigationStack.isEmpty
              ? 'My Roadmaps'
              : viewModel.navigationStack.last['name'],
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Builder(builder: (context) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (viewModel.errorMessage != null &&
            (viewModel.navigationStack.isEmpty
                ? viewModel.goalTasks.isEmpty
                : viewModel.currentLevelItems.isEmpty)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: viewModel.errorMessage=="No data found"?
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "No financial plans set up yet. Create one with the AI planner!",
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Create Plan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async{
                      Navigator.of(context).pop(); // Close the modal bottom sheet
                      await Future.delayed(const Duration(milliseconds: 200)); // Optional: smooth transition
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const GoalInputPage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            final offsetAnimation = Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(animation);
                            return SlideTransition(position: offsetAnimation, child: child);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ):
              Text(viewModel.errorMessage!,
                  style: const TextStyle(color: Color.fromARGB(255, 255, 0, 0), fontSize: 16),
                  textAlign: TextAlign.center),
            ),
          );
        }
        return viewModel.navigationStack.isEmpty
            ? _buildGoalView(context, viewModel)
            : _buildItemsList(context, viewModel);
      }),
    );

    if (widget.isModal) {
      return mainContent;
    }

    return WillPopScope(
      onWillPop: () async {
        if (viewModel.navigationStack.isNotEmpty) {
          await viewModel.goBack();
          return false;
        }
        return true;
      },
      child: mainContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<RoadmapViewModel>(
        builder: (context, viewModel, child) {
          return _buildScaffold(context, viewModel);
        },
      ),
    );
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
          width: bannerAd.size.width.toDouble(),
          height: bannerAd.size.height.toDouble(),
          child: AdWidget(ad: bannerAd),
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


  Widget _buildStartMilestoneButton(
      BuildContext context, TaskHiveModel milestone) {
    final dashboardViewModel =
        Provider.of<AIFinanceViewModel>(context, listen: false);

    bool isActive = dashboardViewModel.activeMilestone?.id == milestone.id;
    bool isCompleted = milestone.isDone;

    if (isCompleted) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text("Completed",
                style: TextStyle(
                    color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (isActive) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                height: 20,
                width: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 8),
            Text("In Progress",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8,0,8,8),
      child: TextButton.icon(
        icon: const Icon(Icons.play_circle_fill),
        label: const Text("Start this Milestone"),
        style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green.withOpacity(0.8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8))),
        onPressed: () async {
          final result = await dashboardViewModel.startMilestone(milestone);
          if (mounted) {
            if (result == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        "'${milestone.title}' started! Daily tasks are now available on your dashboard."),
                    backgroundColor: Colors.green),
              );
              // Close the modal if it is one
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

}