// File: lib/aisupport/ui/plan_roadmap_screen.dart
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/View_PlanCreation.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart';
import 'package:moneymanager/aisupport/RoadMaps/ViewModel_Roadmap.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:provider/provider.dart';

class PlanRoadmapScreen extends StatelessWidget {
  const PlanRoadmapScreen({super.key});

  void _showItemOptionsMenu(
    BuildContext context,
    RoadmapViewModel viewModel,
    TaskHiveModel taskItem,
    Offset globalPosition,
  ) {
    final bool isGoalTask = taskItem.taskLevel == TaskLevelName.Goal && viewModel.navigationStack.isEmpty;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPosition.dx, globalPosition.dy, MediaQuery.of(context).size.width - globalPosition.dx, MediaQuery.of(context).size.height - globalPosition.dy),
      items: [
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Delete'))),
        if (isGoalTask || taskItem.taskLevel == TaskLevelName.Goal) // Allow "Bring to Chat" only for Goal tasks
          const PopupMenuItem(value: 'bringToChat', child: ListTile(leading: Icon(Icons.chat_bubble_outline), title: Text('Bring to Chat/Refine'))),
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
        case 'bringToChat':
          // Ensure we get the root goal task if 'taskItem' is a sub-task but we are bringing the whole plan to chat.
          // However, the menu item is only shown for Goal tasks currently based on `isGoalTask`.
          // If `taskItem` is guaranteed to be the root Goal, then:
           TaskHiveModel? rootGoalTask = taskItem;
           if(taskItem.taskLevel != TaskLevelName.Goal && viewModel.currentlyViewedGoalRoot != null){
             // This case should ideally not happen if the menu is restricted
             // but as a fallback, use the currently viewed goal root if 'taskItem' is a child
             rootGoalTask = viewModel.currentlyViewedGoalRoot;
           } else if (taskItem.taskLevel != TaskLevelName.Goal) {
             // If we can't find the root, show an error or disable "bring to chat" for non-goals
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cannot refine. Root goal not identified."), backgroundColor: Colors.orange),
              );
              return;
           }


          if (rootGoalTask != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => ChangeNotifierProvider(
                  create: (_) => PlanCreationViewModel(
                    planRepository: Provider.of<PlanRepository>(context, listen: false),
                    existingPlanRootTask: rootGoalTask,
                  ),
                  child: const PlanCreationScreen(),
                ),
              ),
            );
          }
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
        title: Text('Edit ${task.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: purposeController, decoration: const InputDecoration(labelText: 'Purpose'), maxLines: 3),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Estimated Duration')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'title': titleController.text,
                'purpose': purposeController.text,
                'duration': durationController.text,
              });
            },
            child: const Text('Save'),
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
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  Widget _buildGoalGrid(BuildContext context, RoadmapViewModel viewModel) {
    if (viewModel.goalTasks.isEmpty && !viewModel.isLoading) {
      return Center(child: Text(viewModel.errorMessage ?? "No financial plans set up yet. Create one with the AI planner!", style: const TextStyle(color: Colors.white54, fontSize: 16)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1, // Or 2 if you prefer
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 3 / 1.5, // Adjust as needed
      ),
      itemCount: viewModel.goalTasks.length,
      itemBuilder: (context, index) {
        final goalTask = viewModel.goalTasks[index];
        return GestureDetector(
          onLongPressStart: (details) {
            _showItemOptionsMenu(context, viewModel, goalTask, details.globalPosition);
          },
          child: Card(
            color: Colors.deepPurple,
            elevation: 4,
            child: InkWell(
              onTap: () => viewModel.navigateToTaskChildren(goalTask),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column( // Changed to Column for better layout
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        goalTask.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Duration: ${goalTask.duration}",
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      const Icon(Icons.arrow_circle_right_rounded, color: Colors.white, size: 30)
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        bool hasChildren = item.taskLevel != TaskLevelName.Daily; // Daily tasks are the lowest level

        return GestureDetector(
          onLongPressStart: (details) {
            _showItemOptionsMenu(context, viewModel, item, details.globalPosition);
          },
          child: Card(
            color: Colors.deepPurple.shade400, // Slightly different shade for sub-items
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ListTile(
              title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  if (item.purpose != null && item.purpose!.isNotEmpty)
                    Text("Purpose: ${item.purpose}", style: const TextStyle(color: Colors.white70)),
                  const Divider(color: Colors.white24),
                  Text("Duration: ${item.duration}", style: const TextStyle(color: Colors.white70)),
                ],
              ),
              trailing: hasChildren ? const Icon(Icons.chevron_right, color: Colors.white) : null,
              onTap: () {
                if (hasChildren) {
                  viewModel.navigateToTaskChildren(item);
                }
                // Else: Tapped on a daily task, maybe show details or mark as complete in future
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // It's good practice to get the ViewModel instance once in the build method
    // if you are not using Consumer/Selector for specific parts.
    // However, for `WillPopScope` and other parts, direct access is fine if it's a StatelessWidget.
    // If this were a StatefulWidget, you'd get it in initState or didChangeDependencies.
    // For StatelessWidget with Provider, using Consumer or context.watch is common.
    // Let's assume you might wrap parts of the UI with Consumer or use context.watch.
    final viewModel = Provider.of<RoadmapViewModel>(context); // Or context.watch for auto-rebuild

    return WillPopScope(
      onWillPop: () => viewModel.goBack(),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A), // Dark background
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color.fromARGB(255, 81, 81, 81),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          title: Text(
            viewModel.navigationStack.isEmpty ? 'My Roadmaps' : viewModel.navigationStack.last['name'],
            style: const TextStyle(color: Colors.white),
          ),
          // Back button is implicitly handled by WillPopScope and Navigator
        ),
        body: Builder( // Use Builder to ensure the context has the ViewModel for Consumers/Watch
          builder: (context) {
            // Re-watch here if you need to react to changes for the whole body
            final vm = context.watch<RoadmapViewModel>();

            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.errorMessage != null && (vm.navigationStack.isEmpty ? vm.goalTasks.isEmpty : vm.currentLevelItems.isEmpty) ) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                ),
              );
            }
            return vm.navigationStack.isEmpty
                ? _buildGoalGrid(context, vm)
                : _buildItemsList(context, vm);
          }
        ),
      ),
    );
  }
}