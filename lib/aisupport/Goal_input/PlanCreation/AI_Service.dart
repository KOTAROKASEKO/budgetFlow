// lib/aisupport/services/ai_planning_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';

class AIPlanningService {
  final String _earnThisYear;
  final String _currentSkill;
  final String _preferToEarnMoney;
  final String _userNote;

  AIPlanningService({
    required String earnThisYear,
    required String currentSkill,
    required String preferToEarnMoney,
    required String note,
  })  : _earnThisYear = earnThisYear,
        _currentSkill = currentSkill,
        _preferToEarnMoney = preferToEarnMoney,
        _userNote = note;

  TaskLevelName _determineTargetLevelForBreakdown(TaskLevelName parentLevel) {
    switch (parentLevel) {
      case TaskLevelName.Goal:
        return TaskLevelName.Phase;
      case TaskLevelName.Phase:
        return TaskLevelName.Milestone;
      case TaskLevelName.Milestone:
        return TaskLevelName.Daily;
      case TaskLevelName.Daily:
        throw Exception("Cannot break down Daily tasks further.");
      }
  }

  String _getPromptForLevel(
    TaskLevelName targetOutputLevel,
    String parentContext,
    String combinedNote,
  ) {
    String baseInstruction = """
You are an expert project manager. Your task is to generate a JSON array of actionable sub-tasks for the user.
User's overall financial plan: Earn RM $_earnThisYear.
User's skills: $_currentSkill.
User's preferred earning method: $_preferToEarnMoney.
General notes from the user: $combinedNote.

$parentContext
""";

    String blueprintJsonFormat = """
Each item in the JSON array must follow this strict format:
{
  "title": "string (concise, actionable name for the item)",
  "purpose": "string (briefly explain why this item is important)"
}
Output ONLY a valid JSON array. DO NOT include 'estimated_duration'. DO NOT use markdown.
""";

String milestoneJsonFormat = """
Each item in the JSON array must follow this strict format:
{
  "title": "string (concise, outcome-focused name for the milestone)",
  "purpose": "string (briefly explain why this milestone is strategically important)",
  "definition_of_done": [
    "string (A specific, measurable goal to complete the milestone)",
    "string (Another specific, measurable goal)"
  ]
}
Output ONLY a valid JSON array. DO NOT use markdown.
""";
    
    String dailyTaskJsonFormat = """
Each item in the JSON array must follow this strict format:
{
  "title": "string (a small, clear action for one day)",
  "purpose": "string (briefly explain why this daily action is important)",
  "sub_steps": [
    "string (A very specific, step-by-step instruction.)",
    "string (The second specific step.)"
  ]
}
Output ONLY a valid JSON array. DO NOT include 'estimated_duration'. DO NOT use markdown.
""";




    switch (targetOutputLevel) {
      case TaskLevelName.Phase:
        return """
$baseInstruction
The user wants to break down their goal into high-level Phases. Each Phase is a major strategic stage.
Generate 2 to 4 Phases.
The 'title' should be a clear name for the phase (e.g., 'Foundation & Skill Building').
The 'purpose' should explain the strategic objective of this phase.
$blueprintJsonFormat
""";
      case TaskLevelName.Milestone:
        return """
$baseInstruction
The user wants to break the parent Phase down into concrete **Milestones**.
Generate 2 to 5 Milestones.
- The 'title' should be an outcome (e.g., 'Launch a Complete Portfolio Website').
- The 'purpose' should explain the strategic importance of this milestone.
- The 'definition_of_done' must be an array of 2-4 specific, measurable criteria that define when the milestone is complete.
$milestoneJsonFormat
""";
      case TaskLevelName.Daily:
         return """
$baseInstruction
The user is starting a new Milestone and needs a complete blueprint of all tasks required to finish it.
Generate a comprehensive list of all small, specific **Micro-Tasks** needed to complete this entire Milestone.
- The 'title' must be a small, clear action for a single day. ideally, it should start from 'You'.
- The 'purpose' should explain how this action contributes to the milestone.
- The 'sub_steps' field must contain an array of 2-4 ultra-specific micro-actions.
- All text should be clear and simple.
$dailyTaskJsonFormat
""";
      default:
        throw Exception("Prompt generation for the given task level is not implemented.");
    }
  }

  Future<List<TaskHiveModel>> fetchAIPlan({
    required TaskHiveModel parentTask,
    String? additionalUserInstruction,
  }) async {
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null) throw Exception('GOOGLE_API_KEY not found.');

    final model = GenerativeModel(model: 'models/gemini-1.5-pro', apiKey: apiKey);
    final generationConfig = GenerationConfig(maxOutputTokens: 8192, temperature: 0.1);

    final targetOutputLevel = _determineTargetLevelForBreakdown(parentTask.taskLevel);
    
    final parentContext = "The user wants to break down the following '${parentTask.taskLevel.toString().split('.').last}' task: '${parentTask.title}' (Purpose: ${parentTask.purpose ?? 'N/A'}).";

    String combinedNote = _userNote;
    if (additionalUserInstruction != null && additionalUserInstruction.isNotEmpty) {
      combinedNote += "\nAdditional instruction for this step: $additionalUserInstruction";
    }

    final prompt = _getPromptForLevel(targetOutputLevel, parentContext, combinedNote);
    
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
        final String? goalId = parentTask.goalId;
        newTasks.add(TaskHiveModel.fromAIMap(item, targetOutputLevel, parentTask.id, order++, goalId));
      }
      return newTasks;
    } catch (e) {
      print("Error in AIPlanningService: $e\nPrompt: $prompt");
      rethrow;
    }
  }
}