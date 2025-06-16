// File: lib/aisupport/ui/plan_creation_screen.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// NEW: A reusable widget to apply a gradient to text.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}

class PlanCreationScreen extends StatefulWidget {
  const PlanCreationScreen({super.key});

  @override
  State<PlanCreationScreen> createState() => _PlanCreationScreenState();
}

class _PlanCreationScreenState extends State<PlanCreationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _regenerationTextController =
      TextEditingController();

  late final PlanCreationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<PlanCreationViewModel>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_viewModel.currentGoalTask != null) {
        _goalNameController.text = _viewModel.goalName;
      }
      _viewModel.addListener(_scrollToBottomIfNecessary);
    });
  }
  
  // NEW: Method to handle back navigation and show a confirmation dialog.
  Future<bool> _onWillPop() async {
    // If no plan has been generated, allow popping without a dialog.
    if (_viewModel.taskHierarchy.isEmpty || _viewModel.taskHierarchy.first.isEmpty) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(158, 0, 0, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: Colors.blueGrey.shade700,
            width: 1.5,
          ),
        ),
        elevation: 24,
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          'Would you like to save your plan before leaving?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        actions: <Widget>[
          // Stay Button
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blueGrey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          
          // Discard Button
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
          
          // Save & Leave Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () async {
              final success = await _viewModel.savePlan();
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Plan saved successfully!"),
                      backgroundColor: Colors.green.withOpacity(0.8),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Save failed: ${_viewModel.errorMessage ?? 'Unknown error'}"),
                      backgroundColor: Colors.red.withOpacity(0.8),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  Navigator.of(context).pop(false);
                }
              }
            },
            child: const Text('Save & Leave'),
          ),
        ],
      ),
    );
    // If the dialog is dismissed, stay on the screen (shouldPop will be null).
    return shouldPop ?? false;
  }


  void _scrollToBottomIfNecessary() {
    if (_scrollController.hasClients && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _viewModel.removeListener(_scrollToBottomIfNecessary);
    _scrollController.dispose();
    _goalNameController.dispose();
    _regenerationTextController.dispose();
    super.dispose();
  }

  // WIDGETS: The UI building blocks for the screen

  Widget _buildHierarchyIndicator(PlanCreationViewModel viewModel) {
    TaskLevelName? activeLevel;
    if (viewModel.taskHierarchy.isNotEmpty &&
        viewModel.taskHierarchy.last.isNotEmpty) {
      activeLevel = viewModel.taskHierarchy.last.first.taskLevel;
    }

    final allLevels = [
      TaskLevelName.Phase,
      TaskLevelName.Monthly,
      TaskLevelName.Weekly,
      TaskLevelName.Daily,
    ];

    List<Widget> indicatorWidgets = [];
    for (int i = 0; i < allLevels.length; i++) {
      final level = allLevels[i];
      final isLevelActive = level == activeLevel;
      final levelName = level.toString().split('.').last;

      if (isLevelActive) {
        indicatorWidgets.add(
          GradientText(
            levelName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(255, 214, 130, 255),
                Color.fromARGB(255, 137, 182, 255),
              ],
            ),
          ),
        );
      } else {
        indicatorWidgets.add(
          Text(
            levelName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
        );
      }

      if (i < allLevels.length - 1) {
        indicatorWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(
              Icons.arrow_forward_ios,
              color: Colors.white30,
              size: 14,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: indicatorWidgets,
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskHiveModel task,
      bool isSelected, VoidCallback onTap) {
    Color cardBackgroundColor = isSelected
        ? const Color.fromARGB(160, 104, 58, 183)
        : const Color.fromARGB(154, 255, 255, 255);
    Color textColor = isSelected
        ? const Color.fromARGB(255, 255, 255, 255)
        : const Color.fromARGB(255, 0, 0, 0);
    Color dividerColor = isSelected
        ? const Color.fromARGB(173, 255, 255, 255).withOpacity(0.5)
        : Colors.grey.shade300;
    Color borderColor =
        isSelected ? const Color.fromARGB(169, 124, 77, 255) : Colors.grey.shade400;

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
          width: MediaQuery.of(context).size.width * 0.7 > 280
              ? 280
              : MediaQuery.of(context).size.width * 0.7,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor),
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
                  Text("Purpose:",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
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

  Widget _buildHorizontalShimmerList() {
    return Shimmer.fromColors(
      baseColor: const Color.fromARGB(152, 97, 97, 97),
      highlightColor: const Color.fromARGB(175, 158, 158, 158),
      child: SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          itemBuilder: (context, index) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: const SizedBox(width: 280, height: 240),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color.fromARGB(146, 66, 66, 66),
      highlightColor: const Color.fromARGB(166, 117, 117, 117),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              height: 24,
              width: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          _buildHorizontalShimmerList(),
          const Divider(
              height: 25,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: Colors.white30),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              height: 24,
              width: MediaQuery.of(context).size.width * 0.6,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRegenerateModal(
      BuildContext context, PlanCreationViewModel viewModel) {
    _regenerationTextController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add instruction for regeneration:",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _regenerationTextController,
              decoration: InputDecoration(
                hintText: "e.g., focus on skill development first",
                border: const OutlineInputBorder(),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surface.withOpacity(0.5),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Regenerate Selected Level's Tasks"),
              onPressed: () {
                Navigator.pop(ctx);
                viewModel.regenerateTasksForSelectedParent(
                    _regenerationTextController.text);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavePlanDialog(
      BuildContext context, PlanCreationViewModel viewModel) async {
    _goalNameController.text = viewModel.goalName;
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
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            onPressed: () {
              if (_goalNameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Goal name cannot be empty."),
                      backgroundColor: Colors.red),
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
          SnackBar(
              content: Text("'${viewModel.goalName}' saved successfully!"),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Failed to save: ${viewModel.errorMessage ?? 'Unknown error'}"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PlanCreationViewModel>();
    final theme = Theme.of(context);

    // MODIFIED: Wrapped the Container with WillPopScope
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/aibackground.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              viewModel.currentGoalTask?.userInputDuration != null &&
                      viewModel.currentGoalTask!.userInputDuration!.isNotEmpty
                  ? "Refine: ${viewModel.goalName}"
                  : "AI Goal Planner",
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.white),
            ),
            backgroundColor: Colors.black.withOpacity(0.4),
            elevation: 0,
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHierarchyIndicator(viewModel),
                if (viewModel.isLoading && viewModel.taskHierarchy.isEmpty)
                  Expanded(child: _buildShimmerPlaceholder(context))
                else if (viewModel.errorMessage != null &&
                    viewModel.taskHierarchy.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Error: ${viewModel.errorMessage}",
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else if (viewModel.taskHierarchy.isEmpty &&
                    !viewModel.isLoading)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 60, color: theme.colorScheme.secondary),
                          const SizedBox(height: 16),
                          Text("No plan structure yet.",
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 20),
                          Text("AI is generating your initial plan based on:",
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: Colors.white60)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 8.0),
                            child: Text(
                              viewModel.planUserDuration.isNotEmpty
                                  ? "Target duration: ${viewModel.planUserDuration}"
                                  : "Please wait...",
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (viewModel.isLoading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry Initial Generation"),
                              onPressed: () => viewModel.fetchOrBreakdownTasks(
                                  parentTask: viewModel.currentGoalTask!),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor:
                                      theme.colorScheme.onPrimary),
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
                      itemCount: viewModel.taskHierarchy.length,
                      itemBuilder: (context, levelIndex) {
                        List<TaskHiveModel> currentLevelTasks =
                            viewModel.taskHierarchy[levelIndex];
                        TaskHiveModel? selectedTaskInThisLevel =
                            viewModel.getSelectedTask(levelIndex);

                        TaskHiveModel? parentForThisLevel;
                        String levelTitlePrefix;

                        if (levelIndex == 0) {
                          parentForThisLevel = viewModel.currentGoalTask;
                          levelTitlePrefix =
                              parentForThisLevel?.title ?? "Overall Plan";
                        } else {
                          parentForThisLevel =
                              viewModel.getSelectedTask(levelIndex - 1);
                          levelTitlePrefix =
                              parentForThisLevel?.title ?? "Sub-tasks";
                        }

                        String levelDisplayName = currentLevelTasks.isNotEmpty
                            ? "${currentLevelTasks.first.taskLevel.toString().split('.').last}s"
                            : "Tasks";

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                "$levelDisplayName for: $levelTitlePrefix",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            if (currentLevelTasks.isEmpty &&
                                viewModel.isLoading)
                              _buildHorizontalShimmerList()
                            else if (currentLevelTasks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 20.0),
                                child: Text(
                                  "No $levelDisplayName found or generated for '${parentForThisLevel?.title ?? 'selected item'}'.",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white54),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              SizedBox(
                                height: 240,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: currentLevelTasks.length,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  itemBuilder: (context, taskIndex) {
                                    final task =
                                        currentLevelTasks[taskIndex];
                                    bool isSelected = task.id ==
                                        selectedTaskInThisLevel?.id;
                                    return _buildTaskCard(
                                        context, task, isSelected, () {
                                      viewModel.selectTask(levelIndex, task);
                                    });
                                  },
                                ),
                              ),
                            if (selectedTaskInThisLevel != null &&
                                selectedTaskInThisLevel.taskLevel !=
                                    TaskLevelName.Daily)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 16.0),
                                child: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color.fromARGB(151, 89, 153, 208),
                                          Color.fromARGB(71, 137, 201, 199)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton.icon(
                                      icon: const Padding(
                                        padding: EdgeInsetsGeometry.only(
                                            left: 10),
                                        child: Icon(
                                            Icons.view_timeline_outlined),
                                      ),
                                      label: const Padding(
                                        padding: EdgeInsetsGeometry.only(
                                            right: 10),
                                        child:
                                            Text("<<Breakdown This Task>>"),
                                      ),
                                      onPressed: viewModel.isLoading
                                          ? null
                                          : () => viewModel
                                              .fetchOrBreakdownTasks(
                                                parentTask:
                                                    selectedTaskInThisLevel,
                                                currentHierarchyLevel:
                                                    levelIndex,
                                              ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          side: const BorderSide(
                                              color: Colors.blue),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (levelIndex <
                                viewModel.taskHierarchy.length - 1)
                              const Divider(
                                  height: 25,
                                  thickness: 0.5,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Colors.white30),
                          ],
                        );
                      },
                    ),
                  ),
                if (viewModel.isLoading && viewModel.taskHierarchy.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: _buildHorizontalShimmerList()),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.published_with_changes),
                        label: const Text("Regenerate"),
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _showRegenerateModal(context, viewModel),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.secondary,
                            side: BorderSide(
                                color: theme.colorScheme.secondary)),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: Text(
                            viewModel.currentGoalTask?.userInputDuration !=
                                        null &&
                                    viewModel.currentGoalTask!
                                        .userInputDuration!.isNotEmpty
                                ? "Save Changes"
                                : "Save Plan"),
                        onPressed: (viewModel.isLoading ||
                                viewModel.taskHierarchy.isEmpty ||
                                viewModel.taskHierarchy[0].isEmpty)
                            ? null
                            : () => _showSavePlanDialog(context, viewModel),
                        style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}