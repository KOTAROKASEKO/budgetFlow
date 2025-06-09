// File: lib/aisupport/ui/plan_roadmap_screen.dart
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/View_PlanCreation.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart';
import 'package:moneymanager/aisupport/RoadMaps/ViewModel_Roadmap.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:provider/provider.dart';

// --- MODIFIED: Converted to StatefulWidget and added isModal flag ---
class PlanRoadmapScreen extends StatefulWidget {
  final bool isModal;
  const PlanRoadmapScreen({super.key, this.isModal = false});

  @override
  State<PlanRoadmapScreen> createState() => _PlanRoadmapScreenState();
}

class _PlanRoadmapScreenState extends State<PlanRoadmapScreen> {
  late final RoadmapViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = RoadmapViewModel(
      planRepository: Provider.of<PlanRepository>(context, listen: false),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // ... (All other helper methods like _showItemOptionsMenu, _showEditDialog, etc. remain unchanged) ...
  
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
        crossAxisCount: 1,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 3 / 1.5,
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => ChangeNotifierProvider(
                      create: (_) => PlanCreationViewModel(
                        planRepository: Provider.of<PlanRepository>(context, listen: false),
                        existingPlanRootTask: goalTask,
                      ),
                      child: const PlanCreationScreen(),
                    ),
                  ),
                );
              },
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
        bool hasChildren = item.taskLevel != TaskLevelName.Daily;

        return GestureDetector(
          onLongPressStart: (details) {
            _showItemOptionsMenu(context, viewModel, item, details.globalPosition);
          },
          child: Card(
            color: Colors.deepPurple.shade400,
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
              },
            ),
          ),
        );
      },
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
              child: Text(viewModel.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center),
            ),
          );
        }
        return viewModel.navigationStack.isEmpty
            ? _buildGoalGrid(context, viewModel)
            : _buildItemsList(context, viewModel);
      }),
    );

    // --- NEW: Conditionally wrap with WillPopScope ---
    if (widget.isModal) {
      return mainContent; // If modal, don't use WillPopScope
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
          // Build the UI, now conditionally wrapped by _buildScaffold
          return _buildScaffold(context, viewModel);
        },
      ),
    );
  }
}