// lib/aisupport/services/ai_planning_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:uuid/uuid.dart';

class AIPlanningService {
  final Uuid _uuid = Uuid();
  final String _earnThisYear;
  final String _userPlanDuration;
  final String _currentSkill;
  final String _preferToEarnMoney;
  final String _userNote;

  AIPlanningService({
    required String earnThisYear,
    required String planDuration,
    required String currentSkill,
    required String preferToEarnMoney,
    required String note,
  })  : _earnThisYear = earnThisYear,
        _userPlanDuration = planDuration,
        _currentSkill = currentSkill,
        _preferToEarnMoney = preferToEarnMoney,
        _userNote = note;

  int _parseDurationToMonths(String? durationStr) {
    if (durationStr == null || durationStr.isEmpty) return 6; // Default if unknown
    durationStr = durationStr.toLowerCase();
    final numberPart = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    if (durationStr.contains("year")) return numberPart * 12;
    if (durationStr.contains("month")) return numberPart;
    if (durationStr.contains("week")) return (numberPart / 4).round().clamp(1, 100); // Approx
    if (durationStr.contains("day")) return (numberPart / 30).round().clamp(1, 100); // Approx
    return 6; // Default
  }

  TaskLevelName _determineTargetLevelForInitialBreakdown() {
    int durationInMonths = _parseDurationToMonths(_userPlanDuration);
    if (durationInMonths <= 1) return TaskLevelName.Weekly;
    if (durationInMonths <= 5) return TaskLevelName.Monthly;//below 5month, will have 5 monthly tasks
    return TaskLevelName.Phase;
  }

  TaskLevelName _determineTargetLevelForSubBreakdown(TaskLevelName parentLevel, String parentDuration) {
    // If parent is Goal, use initial logic based on overall plan duration for the first breakdown
    if (parentLevel == TaskLevelName.Goal) {
      return _determineTargetLevelForInitialBreakdown();
    }

    // FIX: The previous implementation had a confusing switch statement that was causing a loop.
    // This revised logic ensures a clear, hierarchical breakdown.
    switch (parentLevel) {
      case TaskLevelName.Phase:
        return TaskLevelName.Monthly;
      case TaskLevelName.Monthly:
        return TaskLevelName.Weekly;
      case TaskLevelName.Weekly:
        return TaskLevelName.Daily;
      case TaskLevelName.Daily:
        // Daily tasks are the lowest level and cannot be broken down further.
        throw Exception("Cannot break down Daily tasks further.");
      default:
        // Handle any unknown or unexpected parent levels.
        throw Exception("Cannot break down $parentLevel further or parent duration is unsuitable.");
    }
  }

  String _getExampleDuration(TaskLevelName level) {
    switch (level) {
      case TaskLevelName.Phase:
        return "3 months";
      case TaskLevelName.Monthly:
        return "1 month";
      case TaskLevelName.Weekly:
        return "1 week";
      case TaskLevelName.Daily:
        return "1 day";
      default:
        return "N/A";
    }
  }

  Future<List<TaskHiveModel>> fetchAIPlan({
    TaskHiveModel? parentTask,
    String? additionalUserInstruction,
  }) async {
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null) throw Exception('GOOGLE_API_KEY not found.');

    final model = GenerativeModel(model: 'models/gemini-1.5-pro', apiKey: apiKey);
    final generationConfig = GenerationConfig(maxOutputTokens: 8192, temperature: 0.2);

    TaskLevelName targetOutputLevel;
    String parentContext;

    if (parentTask == null) { // Initial breakdown for the main Goal
      targetOutputLevel = _determineTargetLevelForInitialBreakdown();
      parentContext = "This is the initial breakdown of the user's main financial goal which has a total duration of $_userPlanDuration.";
    } else { // Breaking down an existing task
      targetOutputLevel = _determineTargetLevelForSubBreakdown(parentTask.taskLevel, parentTask.duration);
      print('chosen task level is : ${parentTask.taskLevel}');
      print('next level : ${targetOutputLevel.toString()}');
      parentContext = "The user wants to break down the following '${parentTask.taskLevel.toString().split('.').last}' task: '${parentTask.title}' (Current Duration: ${parentTask.duration}, Purpose: ${parentTask.purpose ?? 'N/A'}).";
    }

    String combinedNote = _userNote;
    if (additionalUserInstruction != null && additionalUserInstruction.isNotEmpty) {
      combinedNote += "\nAdditional instruction for this step: $additionalUserInstruction";
    }

    String taskNoun = targetOutputLevel.toString().split('.').last.toLowerCase();
    if (taskNoun != "daily" && taskNoun != "phase") taskNoun += "s";

    String prompt = """
You are an AI financial goal strategist.
Your task is to generate a JSON array of actionable sub-$taskNoun for the user.
User's overall financial plan: Earn RM $_earnThisYear within $_userPlanDuration.
Skills: $_currentSkill. Preferred earning method: $_preferToEarnMoney. General notes: $combinedNote.
$parentContext

Generate sub-$taskNoun. Each item must follow this strict JSON format:
{
  "id": "string (UUID v4, unique for each task)",
  "title": "string (concise, actionable, specific to a $taskNoun)",
  "estimated_duration": "string (e.g., '${_getExampleDuration(targetOutputLevel)}', be appropriate for a $taskNoun)",
  "purpose": "string (briefly explain why this $taskNoun is important, plain text)"
}

Provide 2 to 5 sub-$taskNoun.
For Phases (if requested), each phase should be 2-6 months.
For Weekly tasks from a 1-month parent, generate about 4 weekly tasks.
For Daily tasks from a 1-week parent, generate 5-7 daily tasks. Daily tasks must be small and specific.

Output ONLY a valid JSON array. DO NOT use markdown.
Example for $taskNoun:
[
  {
    "id": "${_uuid.v4()}",
    "title": "Example ${targetOutputLevel.toString().split('.').last} Task 1",
    "estimated_duration": "${_getExampleDuration(targetOutputLevel)}",
    "purpose": "Achieve a small part of the larger objective."
  }
]
""";

    try {
      final response = await model.generateContent([Content.text(prompt)], generationConfig: generationConfig);
      if (response.text == null) throw Exception('AI returned no response. Feedback: ${response.promptFeedback}');

      String responseText = response.text!;
      if (responseText.startsWith("```json")) responseText = responseText.substring(7);
      if (responseText.endsWith("```")) responseText = responseText.substring(0, responseText.length - 3);
      responseText = responseText.trim();

      final decodedJson = jsonDecode(responseText);
      if (decodedJson is! List) throw FormatException("AI response is not a JSON list.");

      List<TaskHiveModel> newTasks = [];
      int order = 0;
      for (var item in decodedJson) {
        if (item is! Map<String, dynamic>) throw FormatException("AI list item is not a JSON object.");
        // [MODIFIED] Pass the goalId from the parent task.
        final String? goalId = parentTask?.goalId;
        newTasks.add(TaskHiveModel.fromAIMap(item, targetOutputLevel, parentTask?.id, order++, goalId));
      }
      return newTasks;
    } catch (e) {
      print("Error in AIPlanningService: $e\nPrompt: $prompt");
      rethrow;
    }
  }
}