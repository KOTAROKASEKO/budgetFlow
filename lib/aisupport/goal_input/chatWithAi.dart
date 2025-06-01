import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Already imported if needed
import 'package:moneymanager/aisupport/Database/localDatabase.dart'; //
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart'; //
import 'package:moneymanager/aisupport/models/daily_task_hive.dart'; //
import 'package:moneymanager/aisupport/models/monthly_task_hive.dart'; //
import 'package:moneymanager/aisupport/models/phase_hive.dart'; //
import 'package:moneymanager/aisupport/models/weekly_task_hive.dart'; //
import 'package:moneymanager/apptheme.dart'; //
import 'package:moneymanager/uid/uid.dart'; //
import 'package:uuid/uuid.dart'; //
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatWithAIScreen extends StatefulWidget {
  final String earnThisYear;
  final String duration;
  final String currentSkill;
  final String preferToEarnMoney;
  final String note;
  final UserPlanHive? existingPlanForRefinement; // New parameter
  // final String? focusItemType; // Optional: To indicate which part of the plan to focus on
  // final String? focusItemId;   // Optional: ID of the item to focus on

  const ChatWithAIScreen({
    super.key,
    required this.earnThisYear,
    required this.duration,
    required this.currentSkill,
    required this.preferToEarnMoney,
    required this.note,
    this.existingPlanForRefinement,
  });

  @override
  _ChatWithAIScreenState createState() => _ChatWithAIScreenState();
}

class _ChatWithAIScreenState extends State<ChatWithAIScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _phases = [];
  List<List<Map<String, dynamic>>> _wholeTasks = [];

  final LocalDatabaseService _localDbService = LocalDatabaseService();
  var uuid = Uuid();

  final TextEditingController _regenerationTextController =
      TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? selectedPhase;
  Map<String, dynamic>? _selectedMonthlyTask;
  Map<String, dynamic>?
      _selectedWeeklyTask; // Added for consistency if you plan to drill down to daily

  final Map<String, List<Map<String, dynamic>>> _childrenTasksCache = {};

  List<String> goalNameList = []; //
  String goalName = '';

  var _scrollController = ScrollController(); //

  @override
  void initState() {
    super.initState();
    if (widget.existingPlanForRefinement != null) {
      _loadDataFromExistingPlan(widget.existingPlanForRefinement!);
      // Set goalName if it's an existing plan being refined
      goalName = widget.existingPlanForRefinement!.goalName; //
    } else {
      _fetchAIPlan(1,
          isInitialLoad: true); // Initial load for phases if not refining
    }
  }

  void scrollToBottom() {
    //
    if (_scrollController.hasClients) {
      //
      _scrollController.animateTo(
        //
        _scrollController.position.maxScrollExtent, //
        duration: const Duration(milliseconds: 300), //
        curve: Curves.easeOut, //
      ); //
    } //
  }

  // New method to populate state from an existing plan
  void _loadDataFromExistingPlan(UserPlanHive plan) {
    setState(() {
      _isLoading = true; // Start loading state
    });
    // Convert Hive objects back to Map<String, dynamic> for UI consistency
    // and populate _childrenTasksCache if needed for further AI interaction.

    _phases = plan.phases.map((p) {
      //
      final phaseMap = {
        'id': p.id, //
        'title': p.title, //
        'estimated_duration': p.estimatedDuration, //
        'purpose': p.purpose, //
        // 'order': p.order (if needed by UI)
      };
      // Populate cache for its children (monthly tasks)
      String monthlyTasksCacheKey = "level0_${p.title}"; //
      _childrenTasksCache[monthlyTasksCacheKey] = p.monthlyTasks.map((m) {
        //
        final monthlyMap = {
          'id': m.id, //
          'title': m.title, //
          'estimated_duration': m.estimatedDuration, //
          'purpose': m.purpose, //
        };
        // Populate cache for its children (weekly tasks)
        String weeklyTasksCacheKey = "level1_${m.title}"; //
        _childrenTasksCache[weeklyTasksCacheKey] = m.weeklyTasks.map((w) {
          //
          final weeklyMap = {
            'id': w.id, //
            'title': w.title, //
            'estimated_duration': w.estimatedDuration, //
            'purpose': w.purpose, //
          };
          // Populate cache for daily tasks if they exist and are needed for AI interaction
          String dailyTasksCacheKey =
              "level2_${w.title}"; // Key for daily tasks, adapted from your existing logic
          _childrenTasksCache[dailyTasksCacheKey] = w.dailyTasks
              .map((d) => {
                    //
                    'id': d.id, //
                    'title': d.title, //
                    'estimated_duration': d.estimatedDuration, //
                    'purpose': d.purpose, //
                    // 'dueDate': d.dueDate, (if AI needs this level of detail for refinement)
                    // 'status': d.status,
                  })
              .toList();
          return weeklyMap;
        }).toList();
        return monthlyMap;
      }).toList();
      return phaseMap;
    }).toList();

    _wholeTasks.clear();
    _wholeTasks.add(_phases); // Add top-level phases to display initially

    // Optionally, automatically select the first phase or the focused item
    if (_phases.isNotEmpty) {
      selectedPhase = _phases[0];
      scrollToBottom();
    }

    setState(() {
      _isLoading = false; // Done loading
      _errorMessage = null;
    });

    // You might want to show a message or slightly alter the AI prompt if it's for refinement.
    // e.g., "The user wants to refine or continue working on the following plan/phase:"
    print("Loaded data from existing plan: ${plan.goalName}");
  }

  DailyTaskHive _mapToDailyTaskHive(Map<String, dynamic> dailyTaskData,
      int order, DateTime dailyTaskStartDate) {
    //
    return DailyTaskHive(
      //
      id: dailyTaskData['id'] as String? ?? uuid.v4(), //
      title: dailyTaskData['title'] as String? ?? 'Untitled Daily Task', //
      purpose: dailyTaskData['purpose'] as String?, //
      estimatedDuration: dailyTaskData['estimated_duration'] as String?, //
      dueDate: dailyTaskStartDate, //
      status: 'pending', //
      order: order, //
    );
  }

  WeeklyTaskHive _mapToWeeklyTaskHive(Map<String, dynamic> weeklyTaskData,
      int order, DateTime weeklyTaskStartDate) {
    //
    List<DailyTaskHive> dailyTasks = []; //
    String dailyTasksCacheKey = "level2_${weeklyTaskData['title']}"; //
    List<Map<String, dynamic>>? cachedDailyTasks =
        _childrenTasksCache[dailyTasksCacheKey]; //

    if (cachedDailyTasks != null) {
      //
      int dailyOrder = 0; //
      DateTime currentDailyDate = weeklyTaskStartDate; //
      for (var dailyMap in cachedDailyTasks) {
        //
        dailyTasks.add(
            _mapToDailyTaskHive(dailyMap, dailyOrder++, currentDailyDate)); //
        currentDailyDate = currentDailyDate.add(Duration(days: 1)); //
      }
    }

    return WeeklyTaskHive(
      //
      id: weeklyTaskData['id'] as String? ?? uuid.v4(), //
      title: weeklyTaskData['title'] as String? ?? 'Untitled Weekly Task', //
      estimatedDuration: weeklyTaskData['estimated_duration'] as String, //
      purpose: weeklyTaskData['purpose'] as String, //
      order: order, //
      dailyTasks: dailyTasks, //
    );
  }

  MonthlyTaskHive _mapToMonthlyTaskHive(Map<String, dynamic> monthlyTaskData,
      int order, DateTime monthlyTaskStartDate) {
    //
    List<WeeklyTaskHive> weeklyTasks = []; //
    String weeklyTasksCacheKey = "level1_${monthlyTaskData['title']}"; //
    List<Map<String, dynamic>>? cachedWeeklyTasks =
        _childrenTasksCache[weeklyTasksCacheKey]; //

    if (cachedWeeklyTasks != null) {
      //
      int weeklyOrder = 0; //
      DateTime currentWeeklyDate = monthlyTaskStartDate; //
      for (var weeklyMap in cachedWeeklyTasks) {
        //
        weeklyTasks.add(_mapToWeeklyTaskHive(
            weeklyMap, weeklyOrder++, currentWeeklyDate)); //
        currentWeeklyDate = currentWeeklyDate.add(Duration(days: 7)); //
      }
    }

    return MonthlyTaskHive(
      //
      id: monthlyTaskData['id'] as String? ?? uuid.v4(), //
      title: monthlyTaskData['title'] as String? ?? 'Untitled Monthly Task', //
      estimatedDuration: monthlyTaskData['estimated_duration'] as String, //
      purpose: monthlyTaskData['purpose'] as String, //
      order: order, //
      weeklyTasks: weeklyTasks, //
    );
  }

  PhaseHive _mapToPhaseHive(
      Map<String, dynamic> phaseData, int order, DateTime phaseStartDate) {
    //
    List<MonthlyTaskHive> monthlyTasks = []; //
    String monthlyTasksCacheKey = "level0_${phaseData['title']}"; //
    List<Map<String, dynamic>>? cachedMonthlyTasks =
        _childrenTasksCache[monthlyTasksCacheKey]; //

    if (cachedMonthlyTasks != null) {
      //
      int monthlyOrder = 0; //
      DateTime currentMonthlyDate = phaseStartDate; //
      for (var monthlyMap in cachedMonthlyTasks) {
        //
        monthlyTasks.add(_mapToMonthlyTaskHive(
            monthlyMap, monthlyOrder++, currentMonthlyDate)); //
        currentMonthlyDate = currentMonthlyDate.add(Duration(days: 30)); //
      }
    }

    return PhaseHive(
      //
      id: phaseData['id'] as String? ?? uuid.v4(), //
      title: phaseData['title'] as String? ?? 'Untitled Phase', //
      estimatedDuration: phaseData['estimated_duration'] as String, //
      purpose: phaseData['purpose'] as String, //
      order: order, //
      monthlyTasks: monthlyTasks, //
    );
  }

  Future<void> _savePlanToLocalDB() async {
    //
    if (_phases.isEmpty) {
      //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            const SnackBar(content: Text("No phases to save."))); //
      }
      return;
    }
    if (goalName.isEmpty) {
      //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            const SnackBar(
                content: Text("Please set a goal name before saving."))); //
      }
      return;
    }

    setState(() {
      _isLoading = true;
    }); //

    try {
      List<PhaseHive> hivePhases = []; //
      int phaseOrder = 0; //
      DateTime currentStartDate = DateTime.now(); //

      for (var phaseData in _phases) {
        //
        hivePhases
            .add(_mapToPhaseHive(phaseData, phaseOrder++, currentStartDate)); //
      }

      final userPlan = UserPlanHive(
        //
        goalName: goalName, //
        earnThisYear: widget.earnThisYear, //
        currentSkill: widget.currentSkill, //
        preferToEarnMoney: widget.preferToEarnMoney, //
        note: widget.note, //
        phases: hivePhases, //
        createdAt:
            widget.existingPlanForRefinement?.createdAt ?? DateTime.now(),
        duration:
            widget.duration, // Preserve original creation date if refining
      );

      await _localDbService.saveUserPlan(userPlan); //

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            const SnackBar(content: Text("Plan saved locally successfully!")));
      }
    } catch (e) {
      print("Error saving plan to Local DB: $e"); //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            SnackBar(content: Text("Error saving plan locally: $e"))); //
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        }); //
      }
    }
  }

  String _generateCacheKey(Map<String, dynamic> parentTask, int parentLevel) {
    //
    return "level${parentLevel}_${parentTask['title']}"; //
  }

  Future<void> _fetchAIPlan(
    int breakdownLevelApi, {
    String? additionalNote,
    Map<String, dynamic>? parentTaskToBreakdown,
    bool isInitialLoad = false,
  }) async {
    if (!isInitialLoad &&
        parentTaskToBreakdown == null &&
        breakdownLevelApi > 1) {
      if (mounted) {
        setState(() {
          _errorMessage = "Cannot breakdown without a selected parent task.";
          _isLoading = false;
        });
      }
      return;
    }

    String? cacheKey;
    // parentLevelDisplay is the display level of the PARENT task being broken down
    // e.g., if breaking down a Phase (level 0 in UI), its parentLevelDisplay is 0.
    int parentLevelDisplay = -1;
    bool shouldProceedToAiCall = true; // Assume we'll call the AI by default

    if (parentTaskToBreakdown != null) {
      // breakdownLevelApi: 1 (Phases), 2 (Monthly from Phase), 3 (Weekly from Monthly), 4 (Daily from Weekly)
      // For breakdownLevelApi 2 (Monthly), parent is Phase (level 0).
      // For breakdownLevelApi 3 (Weekly), parent is Monthly (level 1).
      // For breakdownLevelApi 4 (Daily), parent is Weekly (level 2).
      parentLevelDisplay = breakdownLevelApi - 2;
      cacheKey = _generateCacheKey(parentTaskToBreakdown, parentLevelDisplay);

      if (_childrenTasksCache.containsKey(cacheKey)) {
        List<Map<String, dynamic>> cachedTasks = _childrenTasksCache[cacheKey]!;
        if (cachedTasks.isNotEmpty) {
          // Only use cache if it's not empty
          print(
              'Level $breakdownLevelApi tasks loaded from non-empty cache for ${parentTaskToBreakdown['title']}');
          if (mounted) {
            setState(() {
              int currentParentDisplayLevelInWholeTasks = parentLevelDisplay;

              if (_wholeTasks.length >
                  currentParentDisplayLevelInWholeTasks + 1) {
                _wholeTasks.removeRange(
                    currentParentDisplayLevelInWholeTasks + 1,
                    _wholeTasks.length);
              }

              if (_wholeTasks.length ==
                  currentParentDisplayLevelInWholeTasks + 1) {
                _wholeTasks.add(cachedTasks);
              } else {
                print(
                    "Warning: _wholeTasks length issue before adding cached children. Length: ${_wholeTasks.length}, Expected parent display level: $currentParentDisplayLevelInWholeTasks. Cached tasks not added.");
              }

              if (breakdownLevelApi == 2) {
                _selectedMonthlyTask = null;
                _selectedWeeklyTask = null;
              } else if (breakdownLevelApi == 3) {
                _selectedWeeklyTask = null;
              }
              _isLoading = false;
              _errorMessage = null;
            });
          }
          shouldProceedToAiCall = false; // Non-empty cache found and used
        } else {
          print(
              "Cache for $cacheKey found but is empty. Will proceed to API call for level $breakdownLevelApi to generate tasks for ${parentTaskToBreakdown['title']}.");
          // shouldProceedToAiCall remains true
        }
      }
      // If cache key doesn't exist, shouldProceedToAiCall also remains true
    }

    if (!shouldProceedToAiCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
      return; // Exit if non-empty cache was successfully used
    }

    // --- Proceed with AI Call ---
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        if (parentTaskToBreakdown != null) {
          // This is a breakdown action
          // parentLevelDisplay is already calculated.
          // Clear deeper levels in _wholeTasks before fetching new data.
          int currentParentDisplayLevelInWholeTasks = parentLevelDisplay;
          if (_wholeTasks.length > currentParentDisplayLevelInWholeTasks + 1) {
            _wholeTasks.removeRange(
                currentParentDisplayLevelInWholeTasks + 1, _wholeTasks.length);
          }
        } else if (isInitialLoad && breakdownLevelApi == 1) {
          // For initial load of phases, ensure _wholeTasks is clear if starting fresh.
          _wholeTasks.clear();
        }
      });
    }

    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GOOGLE_API_KEY'];

    if (apiKey == null) {
      print('Error: GOOGLE_API_KEY not found in .env file.');
      if (mounted) {
        setState(() {
          _errorMessage = 'API key isn\'t set';
          _isLoading = false;
        });
      }
      return;
    }

    final model =
        GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);
    String combinedNote = widget.note;
    if (additionalNote != null && additionalNote.isNotEmpty) {
      combinedNote += "\nAdditional instruction: $additionalNote";
    }

    String promptForBreakDown;
    String refinementContext = "";

    if (widget.existingPlanForRefinement != null &&
        isInitialLoad &&
        breakdownLevelApi == 1) {
      refinementContext =
          "The user is refining an existing financial plan titled '${widget.existingPlanForRefinement!.goalName}'. Please review and enhance the phases, or generate them if they are missing, keeping the user's overall goal in mind.\n";
    } else if (widget.existingPlanForRefinement != null &&
        parentTaskToBreakdown != null) {
      refinementContext =
          "The user is refining part of an existing financial plan ('${widget.existingPlanForRefinement!.goalName}'). Focus on breaking down the given task: '${parentTaskToBreakdown['title']}'.\n";
    }

    switch (breakdownLevelApi) {
      case 1: // Fetching Phases
        promptForBreakDown = """
You are an AI financial goal manager.

Your task is to generate a JSON array of actionable financial plan phases based on the user's goals, skills, and preferences.

$refinementContext

Each object in the array must follow **strict JSON format**:

{
  "id": "string (UUID)",
  "title": "string",
  "estimated_duration": "string (e.g., '6 months')",
  "purpose": "string (plain text only, no special characters like dollar signs or quotes inside)"
}

**DO NOT use markdown formatting. Output ONLY a valid JSON array**, like this:
[
  {
    "id": "uuid-1",
    "title": "Phase 1: Foundation",
    "estimated_duration": "3 months",
    "purpose": "Build initial skills and resources."
  }
]

User's income goal for this year: RM ${widget.earnThisYear} 
Duration of the plan: ${widget.duration} months
User's current skills: ${widget.currentSkill}  
User's preferred way to earn money: ${widget.preferToEarnMoney}  
User's notes: $combinedNote

Do not use markdown formatting. Output ONLY a valid JSON array.
""";
        break;
      case 2: // Fetching Monthly tasks for selectedPhase
        // parentTaskToBreakdown is selectedPhase here
        promptForBreakDown = """
You are an AI financial goal manager.

Your task is to break down the following financial goal phase into approximately 1 to 6 actionable monthly tasks.

$refinementContext

Each object in the array must follow strict JSON format:

{
  "id": "string (UUID)",
  "title": "string",
  "estimated_duration": "1 month",
  "purpose": "string (plain text only, no special characters like dollar signs or quotes inside)"
}

Phase details:
- Title: "${parentTaskToBreakdown!['title'] ?? ''}"
- Purpose: "${parentTaskToBreakdown['purpose'] ?? ''}"
- Duration: "${parentTaskToBreakdown['estimated_duration'] ?? ''}"

User context:
- Income Goal: ${widget.earnThisYear}
- Current Skills: ${widget.currentSkill}
- Preferred Way to Earn: ${widget.preferToEarnMoney}
- Notes: $combinedNote

**DO NOT use markdown formatting. Output ONLY a valid JSON array**, like this:
[
  {
    "id": "uuid-m1",
    "title": "Month 1 Task",
    "estimated_duration": "1 month",
    "purpose": "Achieve X."
  }
]

Do not use markdown formatting. Output ONLY a valid JSON array.
""";

        break;
      case 3: // Fetching Weekly tasks for _selectedMonthlyTask
        // parentTaskToBreakdown is _selectedMonthlyTask here
        promptForBreakDown = """
You are an AI financial goal manager.

Your task is to break down the following monthly task into approximately 4 actionable weekly sub-tasks.

$refinementContext

Each object in the array must follow strict JSON format:

{
  "id": "string (UUID)",
  "title": "string",
  "estimated_duration": "1 week",
  "purpose": "string (plain text only, no special characters like dollar signs or quotes inside)"
}

Monthly Task details:
- Title: "${parentTaskToBreakdown!['title'] ?? ''}"
- Purpose: "${parentTaskToBreakdown['purpose'] ?? ''}"
- Duration: "${parentTaskToBreakdown['estimated_duration'] ?? ''}"

User context:
User's income goal for this year: RM ${widget.earnThisYear} 
Duration of the plan: ${widget.duration} months
User's current skills: ${widget.currentSkill}  
User's preferred way to earn money: ${widget.preferToEarnMoney}  
User's notes: $combinedNote

**DO NOT use markdown formatting. Output ONLY a valid JSON array**, like this:
[
  {
    "id": "uuid-w1",
    "title": "Weekly Sub-task 1",
    "estimated_duration": "1 week",
    "purpose": "Achieve Y."
  }
]

Do not use markdown formatting. Output ONLY a valid JSON array.
""";

        break;
      case 4: // Fetching Daily tasks for _selectedWeeklyTask
        // parentTaskToBreakdown is _selectedWeeklyTask here
        promptForBreakDown = """
You are an AI financial goal manager.

Your task is to break down the following weekly task into approximately 5 to 7 actionable daily sub-tasks.

$refinementContext

Each object in the array must follow strict JSON format:

{
  "id": "string (UUID)",
  "title": "string",
  "estimated_duration": "string (e.g., '1 day', '2-3 hours')",
  "purpose": "string (plain text only, no special characters like dollar signs or quotes inside)"
}

Weekly Task details:
- Title: "${parentTaskToBreakdown!['title'] ?? ''}"
- Purpose: "${parentTaskToBreakdown['purpose'] ?? ''}"
- Duration: "${parentTaskToBreakdown['estimated_duration'] ?? ''}"

User context:
User's income goal for this year: RM ${widget.earnThisYear} 
Duration of the plan: ${widget.duration} months
User's current skills: ${widget.currentSkill}  
User's preferred way to earn money: ${widget.preferToEarnMoney}  
User's notes: $combinedNote

**DO NOT use markdown formatting. Output ONLY a valid JSON array**, like this:
[
  {
    "id": "uuid-d1",
    "title": "Daily Task 1",
    "estimated_duration": "1 day",
    "purpose": "Accomplish Z."
  }
]

Do not use markdown formatting. Output ONLY a valid JSON array.
""";

      default:
        promptForBreakDown = ""; // Should not happen
    }

    final generationConfig =
        GenerationConfig(maxOutputTokens: 8192, temperature: 0.1);

    try {
      final response = await model.generateContent(
          [Content.text(promptForBreakDown)],
          generationConfig: generationConfig);

      List<Map<String, dynamic>> newTasksFromAI = [];
      String? currentErrorMessage;

      if (response.text != null) {
        print('AI response (Level $breakdownLevelApi) raw: ${response.text}');
        String responseText = response.text!;
        if (responseText.startsWith("```json")) {
          responseText = responseText.substring(7);
          if (responseText.endsWith("```")) {
            responseText = responseText.substring(0, responseText.length - 3);
          }
        }
        responseText = responseText.trim();

        try {
          final decodedJson = jsonDecode(responseText);
          if (decodedJson is List && decodedJson.every((item) => item is Map)) {
            newTasksFromAI = List<Map<String, dynamic>>.from(
                decodedJson.cast<Map<String, dynamic>>());
            for (var task in newTasksFromAI) {
              task.putIfAbsent('id', () => uuid.v4()); // Ensure ID exists
            }
            scrollToBottom();
          } else {
            throw FormatException(
                "Expected JSON list of objects but got ${decodedJson.runtimeType}");
          }
        } catch (e) {
          print('JSON parsing error (Level $breakdownLevelApi): $e');
          print(
              'AI raw data (failed parsing for L$breakdownLevelApi): $responseText');
          currentErrorMessage =
              'AI response format isn\'t valid for Level $breakdownLevelApi.';
        }
      } else {
        print('Null response from Gemini (Level $breakdownLevelApi).');
        if (response.promptFeedback != null) {
          print(
              'Level $breakdownLevelApi - Prompt Feedback: ${response.promptFeedback?.blockReason}');
          response.promptFeedback?.safetyRatings.forEach((rating) {
            print(
                'Level $breakdownLevelApi - Safety Rating: ${rating.category} - ${rating.probability}');
          });
          if (response.promptFeedback?.blockReason != null) {
            currentErrorMessage =
                'AI request blocked: ${response.promptFeedback!.blockReason}';
          } else {
            currentErrorMessage =
                'Could not get a response from AI for Level $breakdownLevelApi.';
          }
        } else {
          currentErrorMessage =
              'Could not get a response from AI for Level $breakdownLevelApi (null text and no feedback).';
        }
      }

      if (mounted) {
        setState(() {
          if (currentErrorMessage != null) {
            _errorMessage = currentErrorMessage;
          } else {
            _errorMessage =
                null; // Clear previous errors if this call was successful
          }

          if (newTasksFromAI.isNotEmpty ||
              (newTasksFromAI.isEmpty && currentErrorMessage == null)) {
            // Process even if AI returns empty list (valid response)
            if (breakdownLevelApi == 1) {
              // Initial load of Phases
              _phases = newTasksFromAI;
              // _wholeTasks was cleared before API call if initialLoad
              _wholeTasks.add(_phases); // Add the new phases
              selectedPhase = _phases.isNotEmpty ? _phases[0] : null;
              _selectedMonthlyTask = null;
              _selectedWeeklyTask = null;
            } else {
              // For breakdowns (Phases -> Monthly, Monthly -> Weekly, etc.)
              if (cacheKey != null) {
                // cacheKey would be set if parentTaskToBreakdown was not null
                _childrenTasksCache[cacheKey] =
                    newTasksFromAI; // Update cache with new AI data
              }

              // parentLevelDisplay would have been set earlier if parentTaskToBreakdown != null
              int currentParentDisplayLevelInWholeTasks = parentLevelDisplay;

              // _wholeTasks should already be trimmed to the parent level (e.g. just [phases])
              // before the AI call, if it was a breakdown.
              if (_wholeTasks.length ==
                  currentParentDisplayLevelInWholeTasks + 1) {
                _wholeTasks
                    .add(newTasksFromAI); // Add the newly fetched children
              } else {
                print(
                    "Error: _wholeTasks length discrepancy AFTER AI call for breakdown level $breakdownLevelApi. Length: ${_wholeTasks.length}, Expected parent level in _wholeTasks: $currentParentDisplayLevelInWholeTasks. New tasks might not display correctly.");
              }

              // Reset selections for levels deeper than the one just loaded
              if (breakdownLevelApi == 2) {
                // Monthly tasks were loaded
                _selectedMonthlyTask = null;
                _selectedWeeklyTask = null;
              } else if (breakdownLevelApi == 3) {
                // Weekly tasks were loaded
                _selectedWeeklyTask = null;
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print(
          'Gemini API call error or other exception (Level $breakdownLevelApi): $e');
      if (e is GenerativeAIException)
        print('GenAI Exception details: ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error during AI communication for Level $breakdownLevelApi.';
          _isLoading = false;
        });
      }
    }
  }

  // Inside aisupport/goal_input/chatWithAi.dart
// Modify the _fetchAIPlan method

  void _showRegenerateModal() {
    //
    // ... (keep existing _showRegenerateModal logic)
    _regenerationTextController.clear(); //
    showModalBottomSheet(
      //
      context: context, //
      isScrollControlled: true, //
      backgroundColor: Theme.of(context).colorScheme.surface, //
      builder: (context) => Padding(
        //
        padding: EdgeInsets.only(
            //
            bottom: MediaQuery.of(context).viewInsets.bottom, //
            top: 20,
            left: 20,
            right: 20), //
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          //
          Text("Add instruction (for initial phases):", //
              style: Theme.of(context).textTheme.titleMedium), //
          SizedBox(height: 10), //
          TextField(
            //
            controller: _regenerationTextController, //
            decoration: InputDecoration(
                //
                hintText: "e.g., focus on skill development first", //
                border: OutlineInputBorder(), //
                filled: true, //
                fillColor: Theme.of(context).colorScheme.background), //
            minLines: 3, maxLines: 5, //
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface), //
          ),
          SizedBox(height: 20), //
          ElevatedButton(
              //
              child: Text("Regenerate Phases"), //
              onPressed: () {
                //
                Navigator.pop(context); //
                _childrenTasksCache.clear(); //
                // When regenerating, it's a new plan, so clear existingPlanForRefinement state if it was set by "Bring to Chat"
                // This might need more thought if "Regenerate" is meant to work ON the existing plan.
                // For now, assuming it starts fresh.
                _fetchAIPlan(1,
                    additionalNote: _regenerationTextController.text,
                    isInitialLoad: true); //
              }),
          SizedBox(height: 20), //
        ]),
      ),
    );
  }

  Future<void> _saveToFirestore() async {
    //
    // This method saves the AI-generated plan to Firestore.
    // If refining an existing plan, this would update it.
    // The `goalName` is crucial here. If widget.existingPlanForRefinement is not null,
    // `goalName` should be pre-filled from it.
    if (_phases.isEmpty) {
      //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            const SnackBar(content: Text("there is no phase to save"))); //
      }
      return;
    }
    if (goalName.isEmpty) {
      // If it's a new plan, goalName might not be set yet from the dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Goal name is not set. Please ensure it's provided before saving.")));
      }
      return;
    }
    setState(() {
      _isLoading = true;
    }); //

    try {
      final userGoalDocRef =
          _firestore.collection('financialGoals').doc(userId.uid); //

      // Save/Update the main user inputs associated with this goal plan
      // If it's a new plan or an update, set these.
      // If the plan was loaded via existingPlanForRefinement, these are its original inputs.
      await userGoalDocRef.set(
          {
            // Using set with merge:true to create or update
            'earnThisYear': widget.earnThisYear, //
            'currentSkill': widget.currentSkill, //
            'preferToEarnMoney': widget.preferToEarnMoney, //
            'note': widget.note, //
            // 'goalName': goalName, // This was previously here, but goalName is usually part of a list or the collection name itself
            'goalNameList': FieldValue.arrayUnion(
                [goalName]), // Add new goalName to the list if it's not there
            'lastUpdatedAt': FieldValue.serverTimestamp(), // Track updates
          },
          SetOptions(
              merge:
                  true)); // Use merge:true to avoid overwriting other fields in financialGoals/{userId}

      WriteBatch batch = _firestore.batch(); //
      final phaseCollectionRef = userGoalDocRef.collection(goalName); //

      // Clear existing data for this goalName if it's a full overwrite/update
      // This is a destructive operation. Be careful if you only want to merge.
      // For a full refresh from AI, clearing old data is often intended.
      if (widget.existingPlanForRefinement != null || true) {
        // Assume overwrite for now
        QuerySnapshot oldPhasesSnapshot = await phaseCollectionRef.get(); //
        for (var doc in oldPhasesSnapshot.docs) {
          //
          // Recursively delete subcollections if necessary (more complex)
          // For now, just deleting phase documents. Subcollections might become orphaned.
          // A proper deep delete would require listing and deleting children.
          batch.delete(doc.reference); //
        }
      }

      int phaseOrder = 0; //
      for (var phaseData in _phases) {
        //
        final phaseDocRef = phaseCollectionRef.doc(
            phaseData['id'] ?? uuid.v4()); // Use AI provided ID or generate new
        batch.set(phaseDocRef, {
          //
          'title': phaseData['title'], //
          'estimated_duration': phaseData['estimated_duration'], //
          'purpose': phaseData['purpose'], //
          'order': phaseOrder++, //
          'createdAt': FieldValue.serverTimestamp(), //
        });

        String monthlyTasksCacheKey = "level0_${phaseData['title']}"; //
        List<Map<String, dynamic>>? monthlyTasks =
            _childrenTasksCache[monthlyTasksCacheKey]; //

        if (monthlyTasks != null && monthlyTasks.isNotEmpty) {
          //
          final monthlyTasksCollectionRef =
              phaseDocRef.collection('monthlyTasks'); //
          int monthlyTaskOrder = 0; //
          for (var monthlyTaskData in monthlyTasks) {
            //
            final monthlyTaskDocRef = monthlyTasksCollectionRef
                .doc(monthlyTaskData['id'] ?? uuid.v4()); //
            batch.set(monthlyTaskDocRef, {
              //
              'title': monthlyTaskData['title'], //
              'estimated_duration': monthlyTaskData['estimated_duration'], //
              'purpose': monthlyTaskData['purpose'], //
              'order': monthlyTaskOrder++, //
            });

            String weeklyTasksCacheKey =
                "level1_${monthlyTaskData['title']}"; //
            List<Map<String, dynamic>>? weeklyTasks =
                _childrenTasksCache[weeklyTasksCacheKey]; //

            if (weeklyTasks != null && weeklyTasks.isNotEmpty) {
              //
              final weeklyTasksCollectionRef =
                  monthlyTaskDocRef.collection('weeklyTasks'); //
              int weeklyTaskOrder = 0; //
              for (var weeklyTaskData in weeklyTasks) {
                //
                final weeklyTaskDocRef = weeklyTasksCollectionRef
                    .doc(weeklyTaskData['id'] ?? uuid.v4()); //
                batch.set(weeklyTaskDocRef, {
                  //
                  'title': weeklyTaskData['title'], //
                  'estimated_duration': weeklyTaskData['estimated_duration'], //
                  'purpose': weeklyTaskData['purpose'], //
                  'order': weeklyTaskOrder++, //
                });

                // Firestore does not store daily tasks under weekly per current chatWithAi logic
                // If it did, they would be saved here. Example from original code:
                // String dailyTaskCacheKey = "level2_${weeklyTaskData['title']}"; // Adjusted from monthlyTaskData
                // List<Map<String, dynamic>>? dailyTasks = _childrenTasksCache[dailyTaskCacheKey];
                // if (dailyTasks != null && dailyTasks.isNotEmpty) {
                //    final dailyTasksCollectionRef = weeklyTaskDocRef.collection('dailyTasks'); // New subcollection
                //    int dailyTaskOrder = 0;
                //    for (var dailyTaskData in dailyTasks) {
                //        final dailyTaskDocRef = dailyTasksCollectionRef.doc(dailyTaskData['id'] ?? uuid.v4());
                //        batch.set(dailyTaskDocRef, { /* daily task fields */ });
                //    }
                // }
              }
            }
          }
        }
      }

      await batch.commit(); //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            const SnackBar(content: Text("プランが正常に保存されました！"))); //
      }
    } catch (e) {
      print("Firestoreへの保存エラー: $e"); //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(//
            SnackBar(content: Text("データの保存中にエラーが発生しました: $e"))); //
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        }); //
      }
    }
  }

  // Inside _ChatWithAIScreenState class

  Widget _buildTaskCard(Map<String, dynamic> task, bool isSelected,
      VoidCallback onTap, BuildContext context) {
    // We will NOT use Theme.of(context) for colors here, as requested.
    // final theme = Theme.of(context); // Remove this line if you're not using theme colors at all

    Color cardBackgroundColor;
    Color textColor;
    Color dividerColor;
    Color borderColor; // For the border of the card

    if (isSelected) {
      cardBackgroundColor =
          Colors.deepPurple; // Selected card background: purple
      textColor = Colors.white; // Selected card text: white
      dividerColor = Colors.white.withOpacity(0.5); // Divider for selected card
      borderColor = Colors.deepPurpleAccent; // Border for selected card
    } else {
      cardBackgroundColor = Colors.white; // Non-selected card background: white
      textColor = Colors.black; // Non-selected card text: black
      dividerColor = Colors.grey.shade300; // Divider for non-selected card
      borderColor = Colors.grey.shade400; // Border for non-selected card
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 8 : 4,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // Use the hardcoded background color
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            // Use the hardcoded border color
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7 > 280
              ? 280 // Max width for cards
              : MediaQuery.of(context).size.width * 0.7, // Responsive width
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task['title'] as String? ?? 'No Title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // You can adjust font size here if needed
                    color: textColor, // Use hardcoded text color
                  ),
                ),
                // Use the hardcoded divider color
                Divider(height: 16, color: dividerColor),
                Text(
                  "Duration: ${task['estimated_duration'] as String? ?? 'N/A'}",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14), // Use hardcoded text color
                ),
                SizedBox(height: 8),
                Text(
                  "Purpose:",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14), // Use hardcoded text color
                ),
                SizedBox(height: 4),
                Text(
                  task['purpose'] as String? ?? 'N/A',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14), // Use hardcoded text color
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); //
    bool canSave =
        _wholeTasks.isNotEmpty && _wholeTasks[0].isNotEmpty && !_isLoading; //
    if (widget.existingPlanForRefinement != null && goalName.isEmpty) {
      // If it's a refinement, goalName should be set from the existing plan.
      // This is a fallback, should be set in initState.
      goalName = widget.existingPlanForRefinement!.goalName; //
    }

    return Scaffold(
      //
      backgroundColor: AppTheme.baseBackground, //
      appBar: AppBar(
        //
        title: Text(
            widget.existingPlanForRefinement != null
                ? "Refine: ${widget.existingPlanForRefinement!.goalName}"
                : "AI Goal Planner",
            style: TextStyle(fontWeight: FontWeight.w500)), //
        backgroundColor: theme.colorScheme.surfaceVariant, //
        elevation: 2, //
      ),
      body: SafeArea(
        //
        child: Column(
          //
          crossAxisAlignment: CrossAxisAlignment.stretch, //
          children: [
            //
            if (_isLoading && _wholeTasks.isEmpty) //
              Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary))) //
            else if (_errorMessage != null) //
              Expanded(
                //
                child: Center(
                  //
                  child: Padding(
                    //
                    padding: const EdgeInsets.all(16.0), //
                    child: Text("Error: $_errorMessage", //
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 16),
                        textAlign: TextAlign.center), //
                  ),
                ),
              )
            else if (_wholeTasks.isEmpty ||
                _wholeTasks[0].isEmpty && !_isLoading) //
              Expanded(
                //
                child: Center(
                  //
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //
                        Icon(Icons.lightbulb_outline,
                            size: 60, color: theme.colorScheme.secondary), //
                        SizedBox(height: 16), //
                        Text("No plan generated yet.",
                            style: theme.textTheme
                                .headlineSmall), // "No suggestions from AI yet." changed for clarity //
                        SizedBox(height: 20), //
                        if (widget.existingPlanForRefinement ==
                            null) // Only show "Generate Plan" if it's not a refinement flow
                          ElevatedButton.icon(
                              icon: Icon(Icons.auto_awesome),
                              label: Text("Generate Plan"),
                              onPressed: _showRegenerateModal,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary, //
                                  foregroundColor:
                                      theme.colorScheme.onPrimary, //
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12))) //
                        else // If refining, perhaps a different message or action
                          Text("Plan loaded for refinement.",
                              style: theme.textTheme.bodyLarge),
                      ]),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: _wholeTasks.length,
                  itemBuilder: (context, levelIndex) {
                    List<Map<String, dynamic>> currentLevelTasks =
                        _wholeTasks[levelIndex];
                    if (currentLevelTasks.isEmpty &&
                        levelIndex > 0 &&
                        !_isLoading) return SizedBox.shrink();

                    String levelTitle;
                    dynamic currentSelection;
                    VoidCallback Function(Map<String, dynamic>) onTapGenerator;
                    Map<String, dynamic>? taskForBreakdownButton; //
                    int breakdownApiLevelForButton = 0; //

                    if (levelIndex == 0) {
                      levelTitle = "Project Phases ✨";
                      currentSelection = selectedPhase;
                      taskForBreakdownButton = selectedPhase;
                      breakdownApiLevelForButton = 2; // To fetch monthly tasks
                      onTapGenerator = (task) => () {
                            setState(() {
                              selectedPhase = task;
                              _selectedMonthlyTask = null;
                              _selectedWeeklyTask = null;
                              if (_wholeTasks.length > 1)
                                _wholeTasks.removeRange(1, _wholeTasks.length);
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              scrollToBottom(); // Call scrollToBottom after the UI has been rebuilt
                            });
                          };
                    } else if (levelIndex == 1) {
                      levelTitle =
                          "Monthly Tasks for: ${selectedPhase?['title'] ?? 'Phase'} 🗓️";
                      currentSelection = _selectedMonthlyTask;
                      taskForBreakdownButton = _selectedMonthlyTask;
                      breakdownApiLevelForButton = 3; // To fetch weekly tasks
                      onTapGenerator = (task) => () {
                            setState(() {
                              _selectedMonthlyTask = task;
                              _selectedWeeklyTask = null;
                              if (_wholeTasks.length > 2)
                                _wholeTasks.removeRange(2, _wholeTasks.length);
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              scrollToBottom(); // Call scrollToBottom after the UI has been rebuilt
                            });
                          };
                    } else if (levelIndex == 2) {
                      // Was levelIndex == 2 (Weekly Tasks)
                      levelTitle =
                          "Weekly Tasks for: ${_selectedMonthlyTask?['title'] ?? 'Month'} 📅"; // Title adjusted for weekly tasks
                      currentSelection =
                          _selectedWeeklyTask; // New selection state
                      taskForBreakdownButton =
                          _selectedWeeklyTask; // Use weekly task for breakdown
                      breakdownApiLevelForButton = 4; // To fetch daily tasks
                      onTapGenerator = (task) => () {
                            setState(() {
                              _selectedWeeklyTask =
                                  task; // Set selected weekly task
                              if (_wholeTasks.length > 3)
                                _wholeTasks.removeRange(3, _wholeTasks.length);
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              scrollToBottom(); // Call scrollToBottom after the UI has been rebuilt
                            });
                          };
                    } else {
                      // Level 3: Daily tasks
                      levelTitle =
                          "Daily Tasks for: ${_selectedWeeklyTask?['title'] ?? 'Week'} 🎯";
                      currentSelection =
                          null; // No selection for the deepest level shown in this UI
                      onTapGenerator = (task) => () {
                            print("Viewed Daily Task: ${task['title']}");
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              scrollToBottom(); // Call scrollToBottom after the UI has been rebuilt
                            });
                          };
                    }

                    Widget _buildTaskCard(
                        Map<String, dynamic> task,
                        bool isSelected,
                        VoidCallback onTap,
                        BuildContext context) {
                      // We will NOT use Theme.of(context) for colors here, as requested.
                      // final theme = Theme.of(context); // Remove this line if you're not using theme colors at all

                      Color cardBackgroundColor;
                      Color textColor;
                      Color dividerColor;
                      Color borderColor; // For the border of the card

                      if (isSelected) {
                        cardBackgroundColor = Colors
                            .deepPurple; // Selected card background: purple
                        textColor = Colors.white; // Selected card text: white
                        dividerColor = Colors.white
                            .withOpacity(0.5); // Divider for selected card
                        borderColor =
                            Colors.deepPurpleAccent; // Border for selected card
                      } else {
                        cardBackgroundColor =
                            Colors.white; // Non-selected card background: white
                        textColor =
                            Colors.black; // Non-selected card text: black
                        dividerColor = Colors
                            .grey.shade300; // Divider for non-selected card
                        borderColor = Colors
                            .grey.shade400; // Border for non-selected card
                      }

                      return GestureDetector(
                        onTap: onTap,
                        child: Card(
                          elevation: isSelected ? 8 : 4,
                          margin:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          // Use the hardcoded background color
                          color: cardBackgroundColor,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              // Use the hardcoded border color
                              color: borderColor,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.7 > 280
                                ? 280 // Max width for cards
                                : MediaQuery.of(context).size.width *
                                    0.7, // Responsive width
                            padding: EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    task['title'] as String? ?? 'No Title',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          16, // You can adjust font size here if needed
                                      color:
                                          textColor, // Use hardcoded text color
                                    ),
                                  ),
                                  // Use the hardcoded divider color
                                  Divider(height: 16, color: dividerColor),
                                  Text(
                                    "Duration: ${task['estimated_duration'] as String? ?? 'N/A'}",
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize:
                                            14), // Use hardcoded text color
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Purpose:",
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize:
                                            14), // Use hardcoded text color
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    task['purpose'] as String? ?? 'N/A',
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize:
                                            14), // Use hardcoded text color
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // Show breakdown button if current level is less than 3 (Phases, Monthly, Weekly) and a parent is selected
                    bool showBreakdownButton =
                        (levelIndex < 3 && taskForBreakdownButton != null); //

                    return Column(
                      //
                      crossAxisAlignment: CrossAxisAlignment.start, //
                      children: [
                        //
                        Padding(
                          //
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), //
                          child: Text(levelTitle,
                              style: TextStyle(
                                //
                                fontSize: 20, fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9), //
                              )),
                        ),
                        if (currentLevelTasks.isEmpty &&
                            _isLoading &&
                            _wholeTasks.length == levelIndex + 1) //
                          Padding(
                            //
                            padding:
                                const EdgeInsets.symmetric(vertical: 50.0), //
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: theme.colorScheme.primary)), //
                          )
                        else if (currentLevelTasks.isEmpty && levelIndex > 0) //
                          Padding(
                            //
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 20.0), //
                            child: Text(
                              //
                              levelIndex == 1
                                  ? "Select a phase and click 'Breakdown' to see its monthly tasks." //
                                  : (levelIndex == 2
                                      ? "Select a monthly task and click 'Breakdown' to see its weekly actions." //
                                      : "Select a weekly task and click 'Breakdown' to see its daily actions."),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.outline), //
                              textAlign: TextAlign.center, //
                            ),
                          )
                        else
                          SizedBox(
                            //
                            height: 240, // Card height //
                            child: ListView.builder(
                              //
                              scrollDirection: Axis.horizontal, //
                              itemCount: currentLevelTasks.length, //
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0), //
                              itemBuilder: (context, index) {
                                //
                                final task = currentLevelTasks[index]; //
                                bool isSelected = task == currentSelection; //
                                return _buildTaskCard(task, isSelected,
                                    onTapGenerator(task), context); //
                              },
                            ),
                          ),
                        if (showBreakdownButton)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 16.0),
                            child: Center(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.view_timeline_outlined),
                                label: Text(
                                    "Breakdown: ${taskForBreakdownButton['title']}"),
                                onPressed: _isLoading
                                    ? null
                                    : () => _fetchAIPlan(
                                        breakdownApiLevelForButton,
                                        parentTaskToBreakdown:
                                            taskForBreakdownButton),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.secondaryContainer,
                                    foregroundColor:
                                        theme.colorScheme.onSecondaryContainer,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    textStyle: theme.textTheme.labelLarge //
                                    ),
                              ),
                            ),
                          ),
                        if (levelIndex < _wholeTasks.length - 1) //
                          Divider(
                              height: 25,
                              thickness: 0.5,
                              indent: 16,
                              endIndent: 16,
                              color: theme.dividerColor), //
                      ],
                    );
                  },
                ),
              ),
            if (_isLoading && _wholeTasks.isNotEmpty) //
              Padding(
                //
                padding: const EdgeInsets.all(16.0), //
                child: Center(
                    child: LinearProgressIndicator(
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  minHeight: 2,
                )), //
              ),
            Padding(
              //
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12.0), //
              child: Row(
                //
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, //
                children: [
                  //
                  OutlinedButton.icon(
                    //
                    icon: Icon(Icons.published_with_changes), //
                    label: Text("Regen Phases"), //
                    onPressed: _isLoading ? null : _showRegenerateModal, //
                    style: OutlinedButton.styleFrom(
                        //
                        foregroundColor: theme.colorScheme.secondary, //
                        side: BorderSide(
                            color: theme.colorScheme.secondary
                                .withOpacity(0.7)), //
                        padding: EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10)), //
                  ),
                  FilledButton.icon(
                    //
                    icon: Icon(Icons.save_alt_outlined), //
                    label: Text(widget.existingPlanForRefinement != null
                        ? "Save Changes"
                        : "Save Plan"), // Text updated for refinement
                    onPressed: !canSave //
                        ? null
                        : () {
                            //
                            // If it's a new plan, goalName is taken from the dialog.
                            // If it's an existing plan, goalName is already set.
                            if (widget.existingPlanForRefinement == null &&
                                goalName.isEmpty) {
                              // Show dialog to get goalName ONLY IF it's a new plan and goalName isn't set
                              showDialog(
                                //
                                context: context, //
                                builder: (context) {
                                  //
                                  final TextEditingController
                                      _goalNameController =
                                      TextEditingController(); //
                                  return AlertDialog(
                                    //
                                    shape: RoundedRectangleBorder(
                                      //
                                      borderRadius:
                                          BorderRadius.circular(20), //
                                    ),
                                    title: Text("Set Goal Name"), //
                                    content: TextField(
                                      //
                                      controller: _goalNameController, //
                                      decoration: InputDecoration(
                                        //
                                        hintText: "Enter goal name", //
                                        border: OutlineInputBorder(
                                          //
                                          borderRadius:
                                              BorderRadius.circular(30), //
                                        ),
                                        filled: true, //
                                        fillColor:
                                            theme.colorScheme.surfaceVariant, //
                                      ),
                                    ),
                                    actions: [
                                      //
                                      ElevatedButton(
                                        //
                                        style: ElevatedButton.styleFrom(
                                          //
                                          backgroundColor: Colors.purple, //
                                          foregroundColor: Colors.white, //
                                          shape: RoundedRectangleBorder(
                                            //
                                            borderRadius:
                                                BorderRadius.circular(30), //
                                          ),
                                        ),
                                        onPressed: () {
                                          //
                                          if (_goalNameController.text
                                              .trim()
                                              .isNotEmpty) {
                                            //
                                            setState(() {
                                              //
                                              goalName = _goalNameController
                                                  .text
                                                  .trim(); //
                                              // goalNameList.add(goalName); // This list isn't directly used for saving unique goal names here. Firestore's arrayUnion handles uniqueness.
                                            });
                                            Navigator.of(context).pop(); //
                                            _saveToFirestore(); //
                                            _savePlanToLocalDB(); //
                                          }
                                        },
                                        child: Text("Save the plan"), //
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // If goalName is already set (either existing plan or new plan dialog already shown)
                              _saveToFirestore(); //
                              _savePlanToLocalDB(); //
                            }
                          },
                    style: FilledButton.styleFrom(
                        //
                        backgroundColor: theme.colorScheme.primary, //
                        foregroundColor: theme.colorScheme.onPrimary, //
                        padding: EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10)), //
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _regenerationTextController.dispose(); //
    super.dispose();
  }
}
