import 'dart:convert'; // for jsonDecode and jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moneymanager/aisupport/Database/localDatabase.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/models/daily_task_hive.dart';
import 'package:moneymanager/aisupport/models/monthly_task_hive.dart';
import 'package:moneymanager/aisupport/models/phase_hive.dart';
import 'package:moneymanager/aisupport/models/weekly_task_hive.dart';
import 'package:moneymanager/apptheme.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:uuid/uuid.dart'; // Ensure this path and userId are correctly set up

class ChatWithAIScreen extends StatefulWidget {
  final String earnThisYear;
  final String currentSkill;
  final String preferToEarnMoney;
  final String note;

  const ChatWithAIScreen({
    super.key,
    required this.earnThisYear,
    required this.currentSkill,
    required this.preferToEarnMoney,
    required this.note,
  });

  @override
  _ChatWithAIScreenState createState() => _ChatWithAIScreenState();
}

class _ChatWithAIScreenState extends State<ChatWithAIScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _phases = []; // Top-level phases
  List<List<Map<String, dynamic>>> _wholeTasks = []; // Current drill-down path displayed

  final LocalDatabaseService _localDbService = LocalDatabaseService(); // Or get from provider/locator
  var uuid = Uuid();

  final TextEditingController _regenerationTextController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? selectedPhase;
  Map<String, dynamic>? _selectedMonthlyTask;

  // Cache for child tasks: Key is like "level0_ParentTaskTitle"
  final Map<String, List<Map<String, dynamic>>> _childrenTasksCache = {};
  
  List<String> goalNameList = [];
  String goalName = '';

  @override
  void initState() {
    super.initState();
    _fetchAIPlan(1, isInitialLoad: true); // Initial load for phases
  }

  DailyTaskHive _mapToDailyTaskHive(Map<String, dynamic> taskData, int order, DateTime startDate) {
  // This is a simplified mapping. You'll need to parse duration and calculate exact due dates.
  // For simplicity, let's assume daily tasks have a duration of 1 day.
  return DailyTaskHive(
    id: taskData['id'] ?? uuid.v4(), // Ensure AI provides or generate one
    title: taskData['title'] ?? 'Untitled Task',
    purpose: taskData['purpose'],
    estimatedDuration: taskData['estimated_duration'],
    dueDate: startDate, // You'll need more sophisticated date calculation
    status: 'pending',
    order: order,
  );
}

// Helper to convert AI response map to WeeklyTaskHive
WeeklyTaskHive _mapToWeeklyTaskHive(Map<String, dynamic> taskData, int order, DateTime phaseStartDate) {
  List<DailyTaskHive> dailyTasks = [];
  if (taskData['daily_tasks'] is List) { // Assuming AI might return nested daily tasks
    int dailyOrder = 0;
    DateTime weeklyStartDate = phaseStartDate; // Calculate based on weekly task order
    (taskData['daily_tasks'] as List).forEach((daily) {
      // You'll need a robust way to determine start dates for each daily task
      dailyTasks.add(_mapToDailyTaskHive(daily, dailyOrder++, weeklyStartDate));
       weeklyStartDate = weeklyStartDate.add(Duration(days: 1)); // Increment for next daily task
    });
  }
  return WeeklyTaskHive(
    id: taskData['id'] ?? uuid.v4(),
    title: taskData['title'] ?? 'Untitled Weekly Task',
    estimatedDuration: taskData['estimated_duration'] ?? '1 week',
    purpose: taskData['purpose'] ?? '',
    order: order,
    dailyTasks: dailyTasks,
  );
}

// Helper to convert AI response map to MonthlyTaskHive
MonthlyTaskHive _mapToMonthlyTaskHive(Map<String, dynamic> taskData, int order, DateTime phaseStartDate) {
  List<WeeklyTaskHive> weeklyTasks = [];
  // Assuming the AI response for weekly tasks is in _childrenTasksCache
  // Key for weekly tasks: "level1_${taskData['title']}" if breakdownLevelApi was 3
  // Key for daily tasks from weekly: "level2_${weeklyTaskData['title']}" if breakdownLevelApi was 4
  // This part requires careful handling of how you retrieve and structure sub-tasks from _childrenTasksCache

  String weeklyTasksCacheKey = "level1_${taskData['title']}"; // From your existing logic
  List<Map<String, dynamic>>? cachedWeeklyTasks = _childrenTasksCache[weeklyTasksCacheKey]; //

  if (cachedWeeklyTasks != null) {
    int weeklyOrder = 0;
    DateTime monthlyStartDate = phaseStartDate; // Calculate based on monthly task order
    for (var weeklyMap in cachedWeeklyTasks) {
       // For daily tasks under this weekly task:
      List<DailyTaskHive> dailySubTasks = [];
      String dailyTasksCacheKey = "level2_${weeklyMap['title']}"; // As per your prompt structure
      List<Map<String, dynamic>>? cachedDailyTasks = _childrenTasksCache[dailyTasksCacheKey];
      if(cachedDailyTasks != null){
        int dailyOrder = 0;
        DateTime weeklyTaskStartDate = monthlyStartDate; // Needs to be accurate
        for(var dailyMap in cachedDailyTasks){
          dailySubTasks.add(_mapToDailyTaskHive(dailyMap, dailyOrder++, weeklyTaskStartDate));
          weeklyTaskStartDate = weeklyTaskStartDate.add(Duration(days: 1)); // Approximation
        }
      }
      weeklyTasks.add(WeeklyTaskHive(
          id: weeklyMap['id'] ?? uuid.v4(),
          title: weeklyMap['title'] ?? 'Untitled Weekly Task',
          estimatedDuration: weeklyMap['estimated_duration'] ?? '1 week',
          purpose: weeklyMap['purpose'] ?? '',
          order: weeklyOrder++,
          dailyTasks: dailySubTasks
      ));
      // monthlyStartDate = monthlyStartDate.add(Duration(days: 7)); // Approximation for next week
    }
  }


  return MonthlyTaskHive(
    id: taskData['id'] ?? uuid.v4(),
    title: taskData['title'] ?? 'Untitled Monthly Task',
    estimatedDuration: taskData['estimated_duration'] ?? '1 month',
    purpose: taskData['purpose'] ?? '',
    order: order,
    weeklyTasks: weeklyTasks,
  );
}


PhaseHive _mapToPhaseHive(Map<String, dynamic> phaseData, int order, DateTime goalStartDate) {
  List<MonthlyTaskHive> monthlyTasks = [];
  // Assuming the AI response for monthly tasks is in _childrenTasksCache
  // Key for monthly tasks: "level0_${phaseData['title']}"
  String monthlyTasksCacheKey = "level0_${phaseData['title']}"; // From your existing logic
  List<Map<String, dynamic>>? cachedMonthlyTasks = _childrenTasksCache[monthlyTasksCacheKey]; //

  if (cachedMonthlyTasks != null) {
    int monthlyOrder = 0;
    DateTime phaseStartDate = goalStartDate; // Calculate start date based on phase order
    for (var monthlyMap in cachedMonthlyTasks) {
      monthlyTasks.add(_mapToMonthlyTaskHive(monthlyMap, monthlyOrder++, phaseStartDate));
      // phaseStartDate = phaseStartDate.add(Duration(days: 30)); // Approximation for next month
    }
  }

  return PhaseHive(
    id: phaseData['id'] ?? uuid.v4(), // Ensure AI provides an ID or generate one
    title: phaseData['title'] ?? 'Untitled Phase',
    estimatedDuration: phaseData['estimated_duration'] ?? 'N/A',
    purpose: phaseData['purpose'] ?? '',
    order: order,
    monthlyTasks: monthlyTasks,
  );
}


Future<void> _savePlanToLocalDB() async { // Renamed from _saveToFirestore
  if (_phases.isEmpty) { //
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No phases to save.")));
    }
    return;
  }
  if (goalName.isEmpty) { //
     if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please set a goal name before saving.")));
    }
    return;
  }

  setState(() { _isLoading = true; }); //

  try {
    List<PhaseHive> hivePhases = [];
    int phaseOrder = 0;
    DateTime currentStartDate = DateTime.now(); // Base start date for the whole plan

    for (var phaseData in _phases) { //
      hivePhases.add(_mapToPhaseHive(phaseData, phaseOrder++, currentStartDate));
      // TODO: Accurately increment currentStartDate based on phaseData['estimated_duration']
    }

    final userPlan = UserPlanHive(
      goalName: goalName, //
      earnThisYear: widget.earnThisYear, //
      currentSkill: widget.currentSkill, //
      preferToEarnMoney: widget.preferToEarnMoney, //
      note: widget.note, //
      phases: hivePhases,
      createdAt: DateTime.now(),
    );

    await _localDbService.saveUserPlan(userPlan);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plan saved locally successfully!")));
    }
  } catch (e) {
    print("Error saving plan to Local DB: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving plan locally: $e")));
    }
  } finally {
    if (mounted) {
      setState(() { _isLoading = false; }); //
    }
  }
}

  String _generateCacheKey(Map<String, dynamic> parentTask, int parentLevel) {
    return "level${parentLevel}_${parentTask['title']}";
  }

  Future<void> _fetchAIPlan(int breakdownLevelApi, {
    String? additionalNote,
    Map<String, dynamic>? parentTaskToBreakdown, // e.g., selectedPhase or _selectedMonthlyTask
    bool isInitialLoad = false,
  }) async {
    if (!isInitialLoad && parentTaskToBreakdown == null && breakdownLevelApi > 1) {
      print("Error: Parent task is null for breakdown level $breakdownLevelApi.");
      setState(() {
        _errorMessage = "Cannot breakdown without a selected parent task.";
        _isLoading = false;
      });
      return;
    }

    String? cacheKey;
    int parentLevelDisplay = -1;

    if (parentTaskToBreakdown != null) {
      parentLevelDisplay = (breakdownLevelApi == 2) ? 0 : 1; // Level of the parent task
      cacheKey = _generateCacheKey(parentTaskToBreakdown, parentLevelDisplay);

      if (_childrenTasksCache.containsKey(cacheKey)) {

        List<Map<String, dynamic>> cachedTasks = _childrenTasksCache[cacheKey]!;

        print('Level $breakdownLevelApi tasks loaded from cache for ${parentTaskToBreakdown['title']}');

        setState(() {
          int targetWholeTasksIndex = parentLevelDisplay + 1; // Index for children in _wholeTasks
          while (_wholeTasks.length > targetWholeTasksIndex) {
            _wholeTasks.removeLast();
          }
          if (_wholeTasks.length == targetWholeTasksIndex) {
            _wholeTasks.add(cachedTasks);
          } else if (_wholeTasks.length < targetWholeTasksIndex) {
            // This case should ideally be managed by ensuring parent levels are present
            // For now, let's assume _wholeTasks[parentLevelDisplay] exists
            if(_wholeTasks.length == parentLevelDisplay) _wholeTasks.add(cachedTasks); // If only parent list exists
          }


          if (breakdownLevelApi == 2) _selectedMonthlyTask = null;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GOOGLE_API_KEY'];

    if (apiKey == null) {
      print('Error: GOOGLE_API_KEY not found in .env file.');
      setState(() {
        _errorMessage = 'API key isn\'t set';
        _isLoading = false;
      });
      return;
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);
    String combinedNote = widget.note;
    if (additionalNote != null && additionalNote.isNotEmpty) {
      combinedNote += "\nAdditional instruction: $additionalNote";
    }
    String promptForBreakDown;

    switch (breakdownLevelApi) {
      case 1: // Fetching Phases
        promptForBreakDown = """
You are an AI financial goal manager. Your task is to generate a JSON array of actionable financial tasks based on the user's goals, skills, and preferences.
If the goal is "achieve financial freedom within 5 years," divide it into several broad phases (2–6), based on logical progression and the estimated time required for each phase.
Each phase must include: title (string), estimated_duration (string), purpose (string).
User's income goal for this year: ${widget.earnThisYear}
User's current skills: ${widget.currentSkill}
User's preferred way to earn money: ${widget.preferToEarnMoney}
User's notes: $combinedNote
Output only a JSON array. Do not include markdown formatting. Ensure valid JSON.
""";
        break;
      case 2: // Fetching Monthly tasks for selectedPhase
        if (selectedPhase == null) { /* Handled by initial check */ }
        promptForBreakDown = """
You are an AI financial goal manager. Break down the following phase into actionable 1-month tasks.
For the given phase duration of "${selectedPhase!['estimated_duration'] ?? ''}", generate approximately 4-6 distinct 1-month tasks.
Each task: title (string), estimated_duration (string, fixed to "1 month"), purpose (string).
Phase details: Title: "${selectedPhase!['title'] ?? ''}", Purpose: "${selectedPhase!['purpose'] ?? ''}", Duration: "${selectedPhase!['estimated_duration'] ?? ''}"
User context: Income Goal: ${widget.earnThisYear}, Skills: ${widget.currentSkill}, Preferred Earning: ${widget.preferToEarnMoney}, Notes: $combinedNote
Return ONLY a JSON array of these tasks. Ensure each JSON object is complete and valid. No markdown.
""";
        break;
      case 3: // Fetching Weekly tasks for _selectedMonthlyTask
        if (_selectedMonthlyTask == null) { /* Handled by initial check */ }
        promptForBreakDown = """
You are an AI financial goal manager. Break down the following monthly task into around 4 actionable weekly sub-tasks.
Each sub-task: title (string), estimated_duration (string, typically "1 week"), purpose (string).
Monthly Task details: Title: "${_selectedMonthlyTask!['title'] ?? ''}", Purpose: "${_selectedMonthlyTask!['purpose'] ?? ''}", Duration: "${_selectedMonthlyTask!['estimated_duration'] ?? ''}"
User context: Income Goal: ${widget.earnThisYear}, Skills: ${widget.currentSkill}, Preferred Earning: ${widget.preferToEarnMoney}, Notes: $combinedNote
Output only a JSON array. Example: [{"title": "Weekly sub-task", "estimated_duration": "1 week", "purpose": "Purpose."}]
No markdown. Ensure valid JSON.
""";
        break;
      case 4: // Fetching Daily tasks for _selectedMonthlyTask
        if (_selectedMonthlyTask == null) { /* Handled by initial check */ }
        promptForBreakDown = """
You are an AI financial goal manager. Break down the following weekly task into around 6 actionable daily sub-tasks.
Each sub-task: title (string), estimated_duration (string, typically "1 week"), purpose (string).
Monthly Task details: Title: "${_selectedMonthlyTask!['title'] ?? ''}", Purpose: "${_selectedMonthlyTask!['purpose'] ?? ''}", Duration: "${_selectedMonthlyTask!['estimated_duration'] ?? ''}"
User context: Income Goal: ${widget.earnThisYear}, Skills: ${widget.currentSkill}, Preferred Earning: ${widget.preferToEarnMoney}, Notes: $combinedNote
OUT PUT ONLY A JASON ARRAY. Example: [{"title": "Weekly sub-task", "estimated_duration": "1 week", "purpose": "Purpose."}]
Ensure No markdown and the resopnse is valid JSON.
""";
      default:
        promptForBreakDown = "";
    }

    final generationConfig = GenerationConfig(maxOutputTokens: 8192, temperature: 0.1);

    try {
      final response = await model.generateContent(
          [Content.text(promptForBreakDown)],
          generationConfig: generationConfig);

      // Enhanced Logging
      if (response.candidates.isNotEmpty) {
        print('Level $breakdownLevelApi - Finish Reason: ${response.candidates.first.finishReason}');
      }
      if (response.promptFeedback != null) {
        print('Level $breakdownLevelApi - Prompt Feedback: ${response.promptFeedback?.blockReason}');
        response.promptFeedback?.safetyRatings.forEach((rating) {
          print('Level $breakdownLevelApi - Safety Rating: ${rating.category} - ${rating.probability}');
        });
      }

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
          if (decodedJson is List) {
            List<Map<String, dynamic>> newTasks =
                List<Map<String, dynamic>>.from(decodedJson.cast<Map<String, dynamic>>());

            setState(() {
              if (breakdownLevelApi == 1) {
                _phases = newTasks;
                _wholeTasks.clear();
                _wholeTasks.add(_phases);
                selectedPhase = _phases.isNotEmpty ? _phases[0] : null; // Auto-select first phase
                _selectedMonthlyTask = null;
              } else {
                // Add to cache if fetched from API
                if (cacheKey != null && newTasks.isNotEmpty) {
                  _childrenTasksCache[cacheKey] = newTasks;
                }
                // Update _wholeTasks (similar to cache hit logic)
                 int targetWholeTasksIndex = parentLevelDisplay + 1;
                 while (_wholeTasks.length > targetWholeTasksIndex) {
                   _wholeTasks.removeLast();
                 }
                 if (_wholeTasks.length == targetWholeTasksIndex) {
                    _wholeTasks.add(newTasks);
                 }


                if (breakdownLevelApi == 2) _selectedMonthlyTask = null;
              }
              _isLoading = false;
              _errorMessage = null;
            });
            print('Level $breakdownLevelApi tasks parsed successfully: (${newTasks.length} items)');
          } else {
            throw FormatException("Expected JSON list but got ${decodedJson.runtimeType}");
          }
        } catch (e) {
          print('JSON parsing error (Level $breakdownLevelApi): $e');
          print('AI raw data (failed parsing for L$breakdownLevelApi): $responseText');
          setState(() {
            _errorMessage = 'AI response format isn\'t valid for Level $breakdownLevelApi.';
            _isLoading = false;
          });
        }
      } else {
        print('Null response from Gemini (Level $breakdownLevelApi).');
        setState(() {
          _errorMessage = 'Could not get a response from AI for Level $breakdownLevelApi.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Gemini API call error (Level $breakdownLevelApi): $e');
      if (e is GenerativeAIException) print('GenAI Exception: ${e.message}');
      setState(() {
        _errorMessage = 'Error with AI communication for Level $breakdownLevelApi.';
        _isLoading = false;
      });
    }
  }

  void _showRegenerateModal() {
    _regenerationTextController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20, left: 20, right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Add instruction (for initial phases):",
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 10),
          TextField(
            controller: _regenerationTextController,
            decoration: InputDecoration(
                hintText: "e.g., focus on skill development first",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.background),
            minLines: 3, maxLines: 5,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(height: 20),
          ElevatedButton(
              child: Text("Regenerate Phases"),
              onPressed: () {
                Navigator.pop(context);
                // Clear cache related to old phases if necessary, or let selection handle it.
                // For simplicity, regenerating phases will reset selections and subsequent cached items.
                _childrenTasksCache.clear(); // Simplest way to handle regen of base
                _fetchAIPlan(1, additionalNote: _regenerationTextController.text, isInitialLoad: true);
              }),
          SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _saveToFirestore() async {
    if (_phases.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("保存するフェーズがありません。")));
      }
      return;
    }
    setState(() { _isLoading = true; });

    try {
      // ユーザーの目標プランのルートドキュメント参照
      // このドキュメントに、プラン生成時のユーザー入力などのメタ情報を保存できます。
      // Retrieve the current list


      // Add a new value to the list

      // Reference to the user's financial goals document
      final userGoalDocRef = _firestore.collection('financialGoals').doc(userId.uid);

      // Upload the updated list back to Firestore
      await userGoalDocRef.update({
        'goalName': goalName,
      });

      await userGoalDocRef.set({
        'earnThisYear': widget.earnThisYear,
        'currentSkill': widget.currentSkill,
        'preferToEarnMoney': widget.preferToEarnMoney,
        'note': widget.note,
      });
      // バッチ処理を開始
      WriteBatch batch = _firestore.batch();

      // オプション: ユーザーの入力やプラン全体のメタ情報を保存/更新
      // merge:true にすることで、ドキュメントが存在しない場合は作成し、存在する場合はフィールドをマージします。
      // フェーズを保存するサブコレクションの参照
      final phaseCollectionRef = userGoalDocRef.collection(goalName); //

      // 既存のフェーズドキュメントを削除
      // 注意: この方法ではフェーズドキュメントのみが削除され、そのサブコレクション（古い月次タスクなど）は残り続けます。
      // サブコレクションも完全に削除するには、各ドキュメントを再帰的に読み取り削除するか、Cloud Functions を使用する必要があります。
      // 今回は元のコードの削除ロジックを踏襲し、新しいデータで上書きする形とします。
      // 新しいフェーズは新しいドキュメントIDで作成されるため、古いサブコレクションは直接的には競合しませんが、
      // 「孤児」データとして残る可能性があります。
      // QuerySnapshot oldPhasesSnapshot = await phaseCollectionRef.get(); //
      // for (var doc in oldPhasesSnapshot.docs) { //
      //   batch.delete(doc.reference); //
      // }
      // ここで一度バッチをコミットして削除を確定させることもできますが、
      // 一連の「上書き保存」操作として、最後にまとめてコミットします。

      int phaseOrder = 0;
      for (var phaseData in _phases) {
        // 新しいフェーズドキュメントの参照を生成 (ユニークID)
        final phaseDocRef = phaseCollectionRef.doc();
        batch.set(phaseDocRef, {
          'title': phaseData['title'],
          'estimated_duration': phaseData['estimated_duration'],
          'purpose': phaseData['purpose'],
          'order': phaseOrder++,
          'createdAt': FieldValue.serverTimestamp(), //
        });

        // このフェーズに対応する月次タスクをキャッシュから取得
        String monthlyTasksCacheKey = "level0_${phaseData['title']}"; // _generateCacheKey(phaseData, 0) と同等
        List<Map<String, dynamic>>? monthlyTasks = _childrenTasksCache[monthlyTasksCacheKey];

        if (monthlyTasks != null && monthlyTasks.isNotEmpty) {
          final monthlyTasksCollectionRef = phaseDocRef.collection('monthlyTasks');
          int monthlyTaskOrder = 0;
          for (var monthlyTaskData in monthlyTasks) {
            final monthlyTaskDocRef = monthlyTasksCollectionRef.doc(); // 新しい月次タスクドキュメント
            batch.set(monthlyTaskDocRef, {
              'title': monthlyTaskData['title'],
              'estimated_duration': monthlyTaskData['estimated_duration'],
              'purpose': monthlyTaskData['purpose'],
              'order': monthlyTaskOrder++,
              // 'createdAt': FieldValue.serverTimestamp(), // 必要であれば追加
            });

            // この月次タスクに対応する週次タスクをキャッシュから取得
            String weeklyTasksCacheKey = "level1_${monthlyTaskData['title']}"; // _generateCacheKey(monthlyTaskData, 1) と同等
            List<Map<String, dynamic>>? weeklyTasks = _childrenTasksCache[weeklyTasksCacheKey];

            if (weeklyTasks != null && weeklyTasks.isNotEmpty) {
              final weeklyTasksCollectionRef = monthlyTaskDocRef.collection('weeklyTasks');
              int weeklyTaskOrder = 0;
              for (var weeklyTaskData in weeklyTasks) {
                final weeklyTaskDocRef = weeklyTasksCollectionRef.doc(); // 新しい週次タスクドキュメント
                batch.set(weeklyTaskDocRef, {
                  'title': weeklyTaskData['title'],
                  'estimated_duration': weeklyTaskData['estimated_duration'],
                  'purpose': weeklyTaskData['purpose'],
                  'order': weeklyTaskOrder++,
                  // 'createdAt': FieldValue.serverTimestamp(), // 必要であれば追加
                });
              }
            }

            String dailyTaskCacheKey = "level2_${monthlyTaskData['title']}"; // _generateCacheKey(monthlyTaskData, 1) と同等
            List<Map<String, dynamic>>? dailyTasks = _childrenTasksCache[dailyTaskCacheKey];

            if (dailyTasks != null && dailyTasks.isNotEmpty) {
              final weeklyTasksCollectionRef = monthlyTaskDocRef.collection('weeklyTasks');
              int weeklyTaskOrder = 0;
              for (var dailyTaskData in dailyTasks) {
                final weeklyTaskDocRef = weeklyTasksCollectionRef.doc(); // 新しい週次タスクドキュメント
                batch.set(weeklyTaskDocRef, {
                  'title': dailyTaskData['title'],
                  'estimated_duration': dailyTaskData['estimated_duration'],
                  'purpose': dailyTaskData['purpose'],
                  'order': weeklyTaskOrder++,
                  // 'createdAt': FieldValue.serverTimestamp(), // 必要であれば追加
                });
              }
            }
          }
        }
      }

      await batch.commit(); // 全ての変更をコミット
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("プランが正常に保存されました！"))); //
      }
    } catch (e) {
      print("Firestoreへの保存エラー: $e"); //
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("データの保存中にエラーが発生しました: $e"))); //
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; }); //
      }
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task, bool isSelected, VoidCallback onTap, BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 8 : 4,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.5) : theme.cardColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes content apart if card is tall
              children: [
                Text(
                  task['title'] as String? ?? 'No Title',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.textTheme.titleMedium?.color),
                ),
                Divider(height: 16, color: theme.dividerColor.withOpacity(0.5)),
                Text("Duration: ${task['estimated_duration'] as String? ?? 'N/A'}", style: theme.textTheme.bodyMedium),
                SizedBox(height: 8),
                Text("Purpose:", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(task['purpose'] as String? ?? 'N/A', style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis,),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.baseBackground,
      appBar: AppBar(
        title: Text("AI Goal Planner", style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: theme.colorScheme.surfaceVariant, // Slightly different shade for appbar
        elevation: 2,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading && _wholeTasks.isEmpty)
              Expanded(child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)))
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Error: $_errorMessage",
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
                  ),
                ),
              )
            else if (_wholeTasks.isEmpty || _wholeTasks[0].isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lightbulb_outline, size: 60, color: theme.colorScheme.secondary),
                    SizedBox(height: 16),
                    Text("No suggestions from AI yet.", style: theme.textTheme.headlineSmall),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                        icon: Icon(Icons.auto_awesome),
                        label: Text("Generate Plan"),
                        onPressed: _showRegenerateModal,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)))
                  ]),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: _wholeTasks.length,
                  itemBuilder: (context, levelIndex) {
                    List<Map<String, dynamic>> currentLevelTasks = _wholeTasks[levelIndex];
                    if (currentLevelTasks.isEmpty && levelIndex > 0 && !_isLoading) return SizedBox.shrink();

                    String levelTitle;
                    dynamic currentSelection;
                    VoidCallback Function(Map<String, dynamic>) onTapGenerator;
                    Map<String, dynamic>? taskForBreakdownButton;
                    int breakdownApiLevelForButton = 0;


                    if (levelIndex == 0) {
                      levelTitle = "Project Phases ✨";
                      currentSelection = selectedPhase;
                      taskForBreakdownButton = selectedPhase;
                      breakdownApiLevelForButton = 2; // To fetch monthly tasks
                      onTapGenerator = (task) => () => setState(() {
                            selectedPhase = task;
                            _selectedMonthlyTask = null;
                            if (_wholeTasks.length > 1) _wholeTasks.removeRange(1, _wholeTasks.length);
                          });
                    } else if (levelIndex == 1) {
                      levelTitle = "Monthly Tasks for: ${selectedPhase?['title'] ?? 'Phase'} 🗓️";
                      currentSelection = _selectedMonthlyTask;
                      taskForBreakdownButton = _selectedMonthlyTask;
                      breakdownApiLevelForButton = 3; // To fetch weekly tasks
                      onTapGenerator = (task) => () => setState(() {
                            _selectedMonthlyTask = task;
                            if (_wholeTasks.length > 2) _wholeTasks.removeRange(2, _wholeTasks.length);
                          });
                    } else if(levelIndex==2){ // levelIndex == 2 (Weekly Tasks)
                      levelTitle = "Weekly Tasks for: ${selectedPhase?['title'] ?? 'Phase'} 🗓️";
                      currentSelection = _selectedMonthlyTask;
                      taskForBreakdownButton = _selectedMonthlyTask;
                      breakdownApiLevelForButton = 4; // To fetch daily tasks
                      onTapGenerator = (task) => () => setState(() {
                            _selectedMonthlyTask = task;
                            if (_wholeTasks.length > 3) _wholeTasks.removeRange(3, _wholeTasks.length);
                          });
                    }else{
                      levelTitle = "daily Tasks for: ${_selectedMonthlyTask?['title'] ?? 'Month'} 🎯";
                      currentSelection = null; // No selection for the deepest level
                      onTapGenerator = (task) => () => print("Viewed Weekly Task: ${task['title']}");
                    }

                    bool showBreakdownButton = (levelIndex < 2 && taskForBreakdownButton != null);


                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(levelTitle, style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9),
                          )),
                        ),
                        if (currentLevelTasks.isEmpty && _isLoading && _wholeTasks.length == levelIndex +1) // only show loader for the current level being loaded
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 50.0),
                             child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
                           )
                        else if (currentLevelTasks.isEmpty && levelIndex > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                            child: Text(
                                levelIndex == 1 ? "Select a phase and click 'Breakdown' to see its monthly tasks."
                                                : "Select a monthly task and click 'Breakdown' to see its weekly actions.",
                                style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
                                textAlign: TextAlign.center,
                            ),
                          )
                        else
                          SizedBox(
                            height: 240, // Card height
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: currentLevelTasks.length,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              itemBuilder: (context, index) {
                                final task = currentLevelTasks[index];
                                bool isSelected = task == currentSelection;
                                return _buildTaskCard(task, isSelected, onTapGenerator(task), context);
                              },
                            ),
                          ),
                        if (showBreakdownButton)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                            child: Center(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.view_timeline_outlined),
                                label: Text("Breakdown: ${taskForBreakdownButton['title']}"),
                                onPressed: _isLoading ? null : () => _fetchAIPlan(breakdownApiLevelForButton, parentTaskToBreakdown: taskForBreakdownButton),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.secondaryContainer,
                                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    textStyle: theme.textTheme.labelLarge
                                ),
                              ),
                            ),
                          ),
                        if (levelIndex < _wholeTasks.length - 1)
                          Divider(height: 25, thickness: 0.5, indent: 16, endIndent: 16, color: theme.dividerColor),
                      ],
                    );
                  },
                ),
              ),
            if (_isLoading && _wholeTasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: LinearProgressIndicator(color: theme.colorScheme.primary, backgroundColor: theme.colorScheme.surfaceVariant, minHeight: 2,)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal:16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.published_with_changes),
                    label: Text("Regen Phases"),
                    onPressed: _isLoading ? null : _showRegenerateModal,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                        side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.7)),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
                  ),
                  FilledButton.icon( // Using FilledButton for primary action
                    icon: Icon(Icons.save_alt_outlined),
                    label: Text("Save Phases"),
                    onPressed: _isLoading || (_wholeTasks.isNotEmpty && _wholeTasks[0].isEmpty)
                      ? null
                      : () {
                        showDialog(
                          context: context,
                          builder: (context) {
                          final TextEditingController _goalNameController = TextEditingController();
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text("Set Goal Name"),
                            content: TextField(
                            controller: _goalNameController,
                            decoration: InputDecoration(
                              hintText: "Enter goal name",
                              border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                            ),
                            ),
                            actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              ),
                              onPressed: () {
                              if (_goalNameController.text.trim().isNotEmpty) {
                                setState(() {
                                  goalName = _goalNameController.text.trim();
                                  goalNameList.add(goalName);
                                });
                                Navigator.of(context).pop();
                                _saveToFirestore();
                                _savePlanToLocalDB();
                              }
                              },
                              child: Text("Save the plan"),
                            ),
                            ],
                          );
                          },
                        );
                        },
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
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
    _regenerationTextController.dispose();
    super.dispose();
  }
}