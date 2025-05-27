// lib/goal_input_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GoalInputPage extends StatefulWidget {
  const GoalInputPage({super.key});

  @override
  State<GoalInputPage> createState() => _GoalInputPageState();
}

class _GoalInputPageState extends State<GoalInputPage> {
  final TextEditingController _earnThisYearController = TextEditingController();
  final TextEditingController _currentSkillController = TextEditingController();
  final TextEditingController _preferToEarnMoneyController = TextEditingController();
   final TextEditingController _noteController = TextEditingController();
  
  bool isLoadingAI = false;

  @override
  void dispose() {
    _earnThisYearController.dispose();
    _currentSkillController.dispose();
    _preferToEarnMoneyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('GoalInputPage build called');
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // アプリ全体の背景色 (暗いグレー)
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Goal Input',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ListView(
            children: [
              SizedBox(height: 24),
              _buildInputField(
                controller: _earnThisYearController,
                hintText: 'How much you gonna earn this year?',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _currentSkillController,
                hintText: 'What is your current skill?',
                maxLines: 4,
                 keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _preferToEarnMoneyController,
                hintText: 'Is there any way you prefer to earn money?',
                maxLines: 4,
                keyboardType: TextInputType.multiline
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _noteController,
                hintText: 'Any additional note',
                maxLines: 4,
                keyboardType: TextInputType.multiline
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async{
                    setState(() {
                        isLoadingAI = true;
                      });
                     showModalBottomSheet(
                      context: context,
                      isDismissible: false, // Prevent dismissing by tapping outside
                      enableDrag: false,    // Prevent dismissing by dragging
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
                      ),
                      builder: (bottomSheetContext) { // Use a different context name if needed
                        // Pass the correct context for the bottom sheet content
                        return loadingAiresponseView();
                      },
                    );
                    await AIplan();
                    setState(() {
                      isLoadingAI = true;
                    });
                    if (mounted) {
                      Navigator.pop(context); // Pops the bottom sheet
                    }
                    
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2), // 鮮やかな紫
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'start',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget loadingAiresponseView() {
  // This widget is now only responsible for displaying the UI.
  return Container(
    padding: const EdgeInsets.all(32.0),
    decoration: const BoxDecoration(
      // The shape is primarily controlled by showModalBottomSheet's shape property.
      // You can still set a color here if needed, but ensure it matches.
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), // Matches the sheet's shape
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.5),
                blurRadius: 12.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/robotChan.gif', // Ensure this path is correct
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error_outline, size: 60, color: Colors.grey);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
        ),
        const SizedBox(height: 20),
        const Text(
          'Generating your financial plan...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color.fromARGB(255, 50, 50, 50),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16), // Bottom padding
      ],
    ),
  );
}
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    var textBoxColor = Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: textBoxColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4), // 影の位置
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        
        fillColor: textBoxColor,
        hintText: hintText,
        hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      cursorColor: Colors.blueAccent,
      ),
    );
  }
  // Sample function to get response from ChatGPT using OpenAI API
  Future<void> AIplan() async {
  // Ensure dotenv is loaded
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GOOGLE_API_KEY']; // Use your Google API Key

    if (apiKey == null) {
      print('Error: GOOGLE_API_KEY not found in .env file.');
      return;
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);

    final now = DateTime.now();
    final String currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Construct the prompt carefully to instruct Gemini to return JSON.
    // Gemini's API for forcing JSON output is via instructions in the prompt
    // and potentially using specific model versions that are better at adhering to it.
    final prompt = """
  You are an AI financial goal manager. Your task is to generate a JSON array of actionable financial tasks for a user, based on their goal, skills, and preferences.

  The output MUST be a valid JSON array where each object represents a task. Do NOT include any other text, explanation, or markdown formatting like ```json before or after the JSON array.

  Each task object must strictly adhere to the following schema:
  [
    {
      "taskId": "string", // Unique identifier for the task (e.g., T001, T002)
      "taskName": "string", // Concise name for the task (e.g., 'Research YouTube Niches')
      "taskDescription": "string", // Detailed explanation of the task
      "dueDate": "YYYY-MM-DD", // Required format: 'YYYY-MM-DD'. This date should be in the future relative to the current date provided in the user prompt. Suggest realistic due dates for the next 3-6 months.
      "priority": "high|medium|low",
      "effort": "low|medium|high",
      "impact": "low|medium|high",
      "status": "pending", // Always 'pending' initially
      "aiGenerated": true, // Always true for these generated tasks
      "isRecurring": false, // true if the task should repeat, false otherwise
      "recurringPattern": "daily|weekly|monthly|custom|yearly", // Only if isRecurring is true. If custom, provide a brief description.
      "subTasks": [ // Array of smaller, actionable steps. Can be empty.
        {"subTaskName": "string", "isCompleted": false} // isCompleted always false initially
      ],
      "notes": "string" // Optional: provide a useful AI tip or note for the task. Can be empty.
    }
  ]

  Generate 5 to 7 specific, measurable, achievable, relevant, and time-bound (SMART) tasks. If the goal involves earning money, focus tasks on leveraging the user's skills and preferred earning methods.

  User's goal: Earn RM ${_earnThisYearController.text} this year.
  User's current skill: ${_currentSkillController.text}.
  User's preferred way to earn money: ${_preferToEarnMoneyController.text}.
  User's additional note: ${_noteController.text}.
  Current date for due date reference: $currentDate.

  Generate 5-7 financial tasks in the specified JSON array format for them to achieve this goal, with realistic due dates spanning the next 3-6 months from today.
  Ensure the output is ONLY the JSON array.
  """;
    final generationConfig = GenerationConfig(
      maxOutputTokens: 1024,
      temperature: 0.7,
    );

    try {
      final response = await model.generateContent(
        [Content.text(prompt)],
        generationConfig: generationConfig,
      );

      if (response.text != null) {
        String responseText = response.text!;
        // Gemini might sometimes wrap the JSON in markdown, try to clean it.
        if (responseText.startsWith("```json")) {
          responseText = responseText.substring(7);
          if (responseText.endsWith("```")) {
            responseText = responseText.substring(0, responseText.length - 3);
          }
        }
        responseText = responseText.trim(); // Trim any leading/trailing whitespace

        try {
          final List<dynamic> parsedTasks = jsonDecode(responseText);
          final List<Map<String, dynamic>> tasksData = parsedTasks.cast<Map<String, dynamic>>();
          print('Successfully parsed AI-generated tasks:');
          tasksData.forEach((task) {
            print('  - Task: ${task['taskName']}, Due: ${task['dueDate']}');
          });
        } catch (e) {
          print('Error parsing AI-generated JSON: $e');
          print('Raw AI response content (failed to parse): $responseText');
        }
      } else {
        print('Failed to get a valid response from Gemini. Response was null.');
        if (response.promptFeedback != null) {
          print('Prompt Feedback: ${response.promptFeedback}');
        }
        if (response.candidates.isNotEmpty && response.candidates.first.finishReason != null) {
          print('Finish Reason: ${response.candidates.first.finishReason}');
          print('Finish Message: ${response.candidates.first.finishMessage}');
        }
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
      if (e is GenerativeAIException) {
        print('Generative AI Exception details: ${e.message}');
      }
    }
  }
}