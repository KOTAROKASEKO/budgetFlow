// File: lib/aisupport/ui/plan_creation_screen.dart
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/apptheme.dart'; // Assuming AppTheme.baseBackground exists
import 'package:provider/provider.dart';

class PlanCreationScreen extends StatefulWidget {
  const PlanCreationScreen({super.key});

  @override
  State<PlanCreationScreen> createState() => _PlanCreationScreenState();
}

class _PlanCreationScreenState extends State<PlanCreationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _regenerationTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize goalNameController if editing/refining an existing plan
    // This is done after the first frame to ensure ViewModel is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<PlanCreationViewModel>(context, listen: false);
      if (viewModel.currentGoalTask != null) {
        _goalNameController.text = viewModel.goalName;
      }
      // Add listener to scroll to bottom when new content is added
      viewModel.addListener(_scrollToBottomIfNecessary);
    });
  }

  void _scrollToBottomIfNecessary() {
    final viewModel = Provider.of<PlanCreationViewModel>(context, listen: false);
    
    // Heuristic: if task hierarchy grew or a new level was added
    // This might need refinement based on specific ViewModel changes.
    // For now, let's scroll after any notification if the scroll controller is attached.
    if (_scrollController.hasClients && mounted) {
       WidgetsBinding.instance.addPostFrameCallback((_) { // Ensure it happens after build
        if (_scrollController.position.maxScrollExtent > 0) {
            _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            );
        }
       });
    }
  }

  @override
  void dispose() {
    Provider.of<PlanCreationViewModel>(context, listen: false)
        .removeListener(_scrollToBottomIfNecessary);
    _scrollController.dispose();
    _goalNameController.dispose();
    _regenerationTextController.dispose();
    super.dispose();
  }

  Widget _buildTaskCard(BuildContext context, TaskHiveModel task, bool isSelected, VoidCallback onTap) {
    // Using the card design from your original chatWithAi.dart
    Color cardBackgroundColor = isSelected ? Colors.deepPurple : Colors.white;
    Color textColor = isSelected ? Colors.white : Colors.black;
    Color dividerColor = isSelected ? Colors.white.withOpacity(0.5) : Colors.grey.shade300;
    Color borderColor = isSelected ? Colors.deepPurpleAccent : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 8 : 4,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: isSelected ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7 > 280 ? 280 : MediaQuery.of(context).size.width * 0.7,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView( // Added to prevent overflow if content is too long
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Ensure card doesn't expand unnecessarily
              children: [
                Text(
                  task.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Divider(height: 16, color: dividerColor),
                Text(
                  "Duration: ${task.duration}",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                if (task.purpose != null && task.purpose!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text("Purpose:", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    task.purpose!,
                    style: TextStyle(color: textColor, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegenerateModal(BuildContext context, PlanCreationViewModel viewModel) {
    _regenerationTextController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add instruction for regeneration:", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _regenerationTextController,
              decoration: InputDecoration(
                hintText: "e.g., focus on skill development first",
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.background.withOpacity(0.5),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Regenerate Selected Level's Tasks"),
              onPressed: () {
                Navigator.pop(ctx);
                viewModel.regenerateTasksForSelectedParent(_regenerationTextController.text);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavePlanDialog(BuildContext context, PlanCreationViewModel viewModel) async {
    _goalNameController.text = viewModel.goalName; // Pre-fill with current name
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Set Goal Name"),
        content: TextField(
          controller: _goalNameController,
          decoration: InputDecoration(
            hintText: "Enter goal name",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              if (_goalNameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Goal name cannot be empty."), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Set & Save"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      viewModel.goalName = _goalNameController.text.trim();
      bool success = await viewModel.savePlan();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'${viewModel.goalName}' saved successfully!"), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst); // Go back to main/home screen
      } else if (!success && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: ${viewModel.errorMessage ?? 'Unknown error'}"), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PlanCreationViewModel>();
    final theme = Theme.of(context); // For theme colors if needed later

    return Scaffold(
      backgroundColor: AppTheme.baseBackground, // Or your preferred background
      appBar: AppBar(
        title: Text(
          viewModel.currentGoalTask?.userInputDuration != null && viewModel.currentGoalTask!.userInputDuration!.isNotEmpty
              ? "Refine: ${viewModel.goalName}"
              : "AI Goal Planner",
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 81, 81, 81), // Similar to roadMapRecord
        elevation: 2,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (viewModel.isLoading && viewModel.taskHierarchy.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (viewModel.errorMessage != null && viewModel.taskHierarchy.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Error: ${viewModel.errorMessage}",
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else if (viewModel.taskHierarchy.isEmpty && !viewModel.isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 60, color: theme.colorScheme.secondary),
                      const SizedBox(height: 16),
                      Text("No plan structure yet.", style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 20),
                       Text("AI is generating your initial plan based on:", style: theme.textTheme.titleMedium?.copyWith(color: Colors.white60)),
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                         child: Text(
                            viewModel.planUserDuration.isNotEmpty ?
                            "Target duration: ${viewModel.planUserDuration}" : "Please wait...",
                            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                       ),
                      if (viewModel.isLoading) const CircularProgressIndicator()
                      // Option to trigger initial breakdown if it failed or didn't run
                      else ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry Initial Generation"),
                          onPressed: () => viewModel.fetchOrBreakdownTasks(parentTask: viewModel.currentGoalTask!), // Assumes currentGoalTask is the root
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
                        )
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: viewModel.taskHierarchy.length + (viewModel.isLoading && viewModel.taskHierarchy.isNotEmpty ? 1 : 0) , // +1 for loading indicator at end if needed
                  itemBuilder: (context, levelIndex) {
                    if (viewModel.isLoading && levelIndex == viewModel.taskHierarchy.length) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ));
                    }

                    List<TaskHiveModel> currentLevelTasks = viewModel.taskHierarchy[levelIndex];
                    if (currentLevelTasks.isEmpty && !viewModel.isLoading && levelIndex > 0) {
                        // This case might indicate that a breakdown resulted in no tasks, or tasks haven't loaded yet.
                        // The parent task should be the one selected at levelIndex-1
                        final parentOfThisLevel = viewModel.getSelectedTask(levelIndex-1);
                        return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                            child: Text(
                                parentOfThisLevel != null ?
                                "No sub-tasks generated for '${parentOfThisLevel.title}'. You can select it and try 'Breakdown' again."
                                : "Select a parent task to see its breakdown.",
                                style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: Colors.white54),
                                textAlign: TextAlign.center,
                            ),
                        );
                    }


                    TaskHiveModel? parentForThisLevel;
                    String levelTitlePrefix;

                    if (levelIndex == 0) {
                      parentForThisLevel = viewModel.currentGoalTask; // The main goal
                      levelTitlePrefix = parentForThisLevel?.title ?? "Overall Plan";
                    } else {
                      parentForThisLevel = viewModel.getSelectedTask(levelIndex - 1);
                      levelTitlePrefix = parentForThisLevel?.title ?? "Sub-tasks";
                    }
                    
                    String levelDisplayName = currentLevelTasks.isNotEmpty
                        ? currentLevelTasks.first.taskLevel.toString().split('.').last + "s"
                        : "Tasks";


                    TaskHiveModel? selectedTaskInThisLevel = viewModel.getSelectedTask(levelIndex);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            "$levelDisplayName for: $levelTitlePrefix",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        if (currentLevelTasks.isEmpty && viewModel.isLoading)
                            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                        else if (currentLevelTasks.isEmpty)
                             Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                                child: Text(
                                    "No $levelDisplayName found or generated for '${parentForThisLevel?.title ?? 'selected item'}'.",
                                    style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: Colors.white54),
                                    textAlign: TextAlign.center,
                                ),
                            )
                        else
                            SizedBox(
                                height: 240, // Fixed height for horizontal list view
                                child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: currentLevelTasks.length,
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                itemBuilder: (context, taskIndex) {
                                    final task = currentLevelTasks[taskIndex];
                                    bool isSelected = task.id == selectedTaskInThisLevel?.id;
                                    return _buildTaskCard(context, task, isSelected, () {
                                    viewModel.selectTask(levelIndex, task);
                                    });
                                },
                                ),
                            ),
                        if (selectedTaskInThisLevel != null && selectedTaskInThisLevel.taskLevel != TaskLevelName.Daily)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                            child: Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.view_timeline_outlined),
                                label: Text("Breakdown: ${selectedTaskInThisLevel.title}"),
                                onPressed: viewModel.isLoading
                                    ? null
                                    : () => viewModel.fetchOrBreakdownTasks(
                                          parentTask: selectedTaskInThisLevel,
                                          currentHierarchyLevel: levelIndex,
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondaryContainer,
                                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        if (levelIndex < viewModel.taskHierarchy.length - 1)
                          const Divider(height: 25, thickness: 0.5, indent: 16, endIndent: 16, color: Colors.white30),
                      ],
                    );
                  },
                ),
              ),
            if (viewModel.isLoading && viewModel.taskHierarchy.isNotEmpty)
                const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.published_with_changes),
                    label: const Text("Regenerate"),
                    onPressed: viewModel.isLoading ? null : () => _showRegenerateModal(context, viewModel),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary, side: BorderSide(color: theme.colorScheme.secondary)),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(viewModel.currentGoalTask?.userInputDuration != null && viewModel.currentGoalTask!.userInputDuration!.isNotEmpty ? "Save Changes" : "Save Plan"),
                    onPressed: (viewModel.isLoading || viewModel.taskHierarchy.isEmpty || viewModel.taskHierarchy[0].isEmpty)
                        ? null
                        : () => _showSavePlanDialog(context, viewModel),
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}