// lib/aisupport/services/ai_planning_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';

class AIPlanningService {
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

  // --- NEW: Method to generate a specific prompt based on the task level ---
  String _getPromptForLevel(
    TaskLevelName targetOutputLevel,
    String parentContext,
    String combinedNote,
  ) {

    //user data
    String baseInstruction = """
You are an expert financial goal strategist. Your task is to generate a JSON array of actionable sub-tasks for the user.
User's overall financial plan: Earn RM $_earnThisYear within $_userPlanDuration.
User's skills: $_currentSkill.
User's preferred earning method: $_preferToEarnMoney.
General notes from the user: $combinedNote.

$parentContext
""";

    String jsonFormatInstruction = """
Each item in the JSON array must follow this strict format:
{
  "title": "string (concise, actionable, specific to the task level)",
  "estimated_duration": "string (appropriate for the task level, e.g., '${_getExampleDuration(targetOutputLevel)}')",
  "purpose": "string (briefly explain why this task is important in plain text)"
}
Output ONLY a valid JSON array. DO NOT use markdown.
""";

    switch (targetOutputLevel) {
      case TaskLevelName.Phase:
        return """
$baseInstruction

The user wants to break down their goal into high-level Phases. Each Phase should be a major strategic stage of their plan, like 'Market Research & Upskilling', 'Building a Portfolio & First Clients', or 'Scaling a Business'.
Generate 2 to 4 Phases. Each phase should have a duration of 2-6 months.
The 'title' should be a clear name for the phase.
The 'purpose' should explain what major milestone this phase accomplishes towards the main goal.

$jsonFormatInstruction
Example:
[
  {
    "title": "Phase 1: Foundation & Skill Validation",
    "estimated_duration": "3 months",
    "purpose": "To build the necessary skills and validate market demand before scaling."
  }
]
""";
      case TaskLevelName.Monthly:
        return """
$baseInstruction

The user wants to break the parent task down into concrete Monthly goals. These should be significant milestones achievable within a month.
Generate 1 to 4 Monthly tasks.
The 'title' should be a clear monthly objective, e.g., 'Launch Freelance Profile and Land First Client' or 'Develop and Launch MVP of the Product'.
The 'purpose' should explain how this month's work contributes to the parent Phase's objective.

$jsonFormatInstruction
Example:
[
  {
    "title": "Month 1: Establish Professional Online Presence",
    "estimated_duration": "1 month",
    "purpose": "To create a high-quality portfolio and profiles on key platforms to attract initial clients."
  }
]
""";
      case TaskLevelName.Weekly:
        return """
$baseInstruction

The user wants to break the parent task down into actionable Weekly tasks. These should be a batch of related tasks that can be completed within one week to move towards the monthly goal.
Generate 3 to 5 Weekly tasks.
The 'title' should be a specific weekly goal, e.g., 'Complete and Polish Online Portfolio' or 'Send 20 Personalized Client Proposals'.
The 'purpose' should explain how this week's actions directly contribute to achieving the monthly goal.

$jsonFormatInstruction
Example:
[
  {
    "title": "Week 1: Draft and Finalize Portfolio Content",
    "estimated_duration": "1 week",
    "purpose": "To prepare all necessary text, images, and links for the online portfolio."
  }
]
""";
      case TaskLevelName.Daily:
        return """
$baseInstruction

The user wants to break their weekly goal into small, specific Daily tasks. These must be very concrete and manageable actions that can be completed in a single day.
Generate 5 to 7 Daily tasks for the week.

- The 'title' must be a small, clear action. Avoid vague goals. Good examples: 'Dedicate 2 hours to the online course', 'Write the 'About Me' section for the freelance profile', 'Research 10 potential clients'. Bad examples: 'Work on project', 'Learn marketing'.
- The 'purpose' should explain how this small action contributes to the weekly target.
- The 'sub_steps' field must contain an array of 2 to 4 ultra-specific, ordered micro-actions that guide the user on exactly how to perform the daily task. This is the most important part. Think of it as a checklist. For example, if the title is 'Research 5 potential clients', the sub_steps could be ['Open LinkedIn Sales Navigator', 'Search for companies in the 'FinTech' industry in Southeast Asia', 'Visit the profiles of 5 relevant companies and save their websites'].
- All of title, purpose, sub_steps should be written with clear, and easy English like the user is 12 years old. 

Each item in the JSON array must follow this strict format:
{
  "title": "string (a small, clear action for the day)",
  "estimated_duration": "string ('1 day')",
  "purpose": "string (briefly explain why this daily action is important)",
  "sub_steps": [
    "string (A very specific, step-by-step instruction. The first step to take.)",
    "string (The second specific step.)"
  ]
}
Output ONLY a valid JSON array. DO NOT use markdown.

Example:
[
  {
    "title": "Research 5 top-rated freelancers in my niche",
    "estimated_duration": "1 day",
    "purpose": "To understand what makes a successful profile and identify best practices.",
    "sub_steps": [
      "1, Open Upwork or Fiverr and navigate to the search bar.",
      "2, Search for '${_currentSkill}' and filter by 'Top Rated'.",
      "3, Analyze the profiles of 5 freelancers, noting their bio, services, and pricing.",
      "4, Save screenshots and notes for inspiration."
    ]
  }
]
""";
      default:
        // This case should ideally not be reached.
        throw Exception("Prompt generation for the given task level is not implemented.");
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
    final generationConfig = GenerationConfig(maxOutputTokens: 8192, temperature: 0.1);

    TaskLevelName targetOutputLevel;
    String parentContext;

    if (parentTask == null) { // Initial breakdown for the main Goal
      targetOutputLevel = _determineTargetLevelForInitialBreakdown();
      parentContext = "This is the initial breakdown of the user's main financial goal which has a total duration of $_userPlanDuration.";
    } else { // Breaking down an existing task
      targetOutputLevel = _determineTargetLevelForSubBreakdown(parentTask.taskLevel, parentTask.duration);
      parentContext = "The user wants to break down the following '${parentTask.taskLevel.toString().split('.').last}' task: '${parentTask.title}' (Current Duration: ${parentTask.duration}, Purpose: ${parentTask.purpose ?? 'N/A'}).";
    }

    String combinedNote = _userNote;
    if (additionalUserInstruction != null && additionalUserInstruction.isNotEmpty) {
      combinedNote += "\nAdditional instruction for this step: $additionalUserInstruction";
    }

    // --- REFACTORED: Use the new method to get a level-specific prompt ---
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