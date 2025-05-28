import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moneymanager/aisupport/Database/localDatabase.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/models/daily_task_hive.dart';
import 'package:moneymanager/aisupport/models/monthly_task_hive.dart';
import 'package:moneymanager/aisupport/models/phase_hive.dart';
import 'package:moneymanager/aisupport/models/weekly_task_hive.dart';
import 'package:moneymanager/uid/uid.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // 実際のユーザーID取得に

// ダミーのユーザーID（実際には FirebaseAuth などから取得してください）

class ProgressManagerScreen extends StatefulWidget {
  const ProgressManagerScreen({super.key});

  @override
  _ProgressManagerScreenState createState() => _ProgressManagerScreenState();
}

class _ProgressManagerScreenState extends State<ProgressManagerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  List<UserPlanHive> _localUserPlans = [];
  // String _userId = DUMMY_USER_ID; // initStateなどで実際のユーザーIDをセット

  bool _isLoading = true;
  String? _errorMessage;
  String directory='';

  List<String> _goalCollectionNames = []; // 表示する目標コレクション名のリスト
  List<Map<String, dynamic>> _currentItems = []; // 現在表示中のアイテムリスト（フェーズ、月次タスク、週次タスク）

  // ナビゲーションスタック: [{'type': 'goal', 'name': 'Goal A', 'id': 'goalA_collection_name'}, {'type': 'phase', 'id': 'phase1_doc_id', 'name': 'Phase X'}]
  List<Map<String, String>> _navigationStack = [];

  @override
  void initState() {
    super.initState();
    _fetchGoalCollectionNames();
  }

  // ... (クラスの他の部分は変更なし)
  List<String> _myGoalCollectionNames = []; // 変数名を明確化

  // ... initState() など ...

  Future<void> _fetchGoalCollectionNamesFromFirestore() async {
  // Keep the user-provided implementation. This populates _myGoalCollectionNames.
  // Ensure it correctly sets _myGoalCollectionNames from data['goalNameList']
  // For example:
  setState(() {
    _isLoading = true; // Should be managed by the caller if part of a larger flow
    // _errorMessage = null; // Clear previous errors
  });
  try {
    DocumentSnapshot userDocSnapshot = await _firestore
        .collection('financialGoals')
        .doc(userId.uid)
        .get();

    if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
      final data = userDocSnapshot.data() as Map<String, dynamic>;
      _myGoalCollectionNames = List<String>.from(data['goalNameList'] ?? []);
      // _goalCollectionNames = _myGoalCollectionNames; // This line might be redundant if the caller updates based on _myGoalCollectionNames
    } else {
      _myGoalCollectionNames = []; // Ensure it's empty if no data
      // _errorMessage = "User data not found in Firestore."; // Caller can set messages
    }
  } catch (e) {
    print("Error fetching goal collection names from Firestore: $e");
    _myGoalCollectionNames = []; // Ensure it's empty on error
    // _errorMessage = "Error fetching goal names from Firestore."; // Caller can set messages
  }
  // setState for isLoading should be managed by the calling function (_fetchAllPlansFromFirestoreAndCache)
}

  Future<UserPlanHive?> _fetchFullPlanDataFromFirestore(String goalName, Map<String, dynamic> userInputs) async {
    List<PhaseHive> phases = [];
    try {
      // 1. Fetch Phases for the goalName
      QuerySnapshot phaseSnapshot = await _firestore
          .collection('financialGoals')
          .doc(userId.uid)
          .collection(goalName) // goalName is the collection of phases
          .orderBy('order')
          .get();

      int phaseOrder = 0;
      for (var phaseDoc in phaseSnapshot.docs) {
        Map<String, dynamic> phaseData = phaseDoc.data() as Map<String, dynamic>;
        List<MonthlyTaskHive> monthlyTasks = [];

        // 2. Fetch Monthly Tasks for each Phase
        QuerySnapshot monthlyTaskSnapshot = await _firestore
            .collection('financialGoals')
            .doc(userId.uid)
            .collection(goalName)
            .doc(phaseDoc.id)
            .collection('monthlyTasks')
            .orderBy('order')
            .get();
        
        int monthlyTaskOrder = 0;
        for (var monthlyTaskDoc in monthlyTaskSnapshot.docs) {
          Map<String, dynamic> monthlyTaskData = monthlyTaskDoc.data() as Map<String, dynamic>;
          List<WeeklyTaskHive> weeklyTasks = []; // Corrected: List of WeeklyTaskHive

          // 3. Fetch Weekly Tasks for each Monthly Task
          // These documents from Firestore are considered "Weekly Tasks"
          QuerySnapshot weeklyTaskSnapshot = await _firestore
              .collection('financialGoals')
              .doc(userId.uid)
              .collection(goalName)
              .doc(phaseDoc.id)
              .collection('monthlyTasks')
              .doc(monthlyTaskDoc.id)
              .collection('weeklyTasks') // This Firestore collection contains "Weekly Task" documents
              .orderBy('order')
              .get();

          int weeklyTaskOrder = 0;
          for (var weeklyTaskDoc in weeklyTaskSnapshot.docs) {
            Map<String, dynamic> weeklyTaskData = weeklyTaskDoc.data() as Map<String, dynamic>;
            
            // The dailyTasks list for this WeeklyTaskHive will be empty,
            // as Firestore (based on current save logic) doesn't store daily tasks under this weekly task document.
            List<DailyTaskHive> dailyTasksForThisWeek = []; 

            // If Firestore DID store daily tasks, e.g., in a sub-collection weeklyTaskDoc.id/dailyTasks
            // or as an array field weeklyTaskData['daily_tasks_array'], you would fetch/map them here.
            // For example, if it was a subcollection:
            /*
            QuerySnapshot dailySnapshot = await weeklyTaskDoc.reference.collection('dailyTasks').orderBy('order').get();
            for (var dailyDoc in dailySnapshot.docs) {
                Map<String, dynamic> dailyData = dailyDoc.data() as Map<String, dynamic>;
                dailyTasksForThisWeek.add(DailyTaskHive(
                    id: dailyDoc.id,
                    title: dailyData['title'] ?? 'Untitled',
                    // ... other DailyTaskHive fields
                    dueDate: (dailyData['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(), // Example
                    order: dailyData['order'] ?? 0, // Example
                ));
            }
            */

            weeklyTasks.add(WeeklyTaskHive(
              id: weeklyTaskDoc.id,
              title: weeklyTaskData['title'] ?? 'Untitled Weekly Task',
              estimatedDuration: weeklyTaskData['estimated_duration'],
              purpose: weeklyTaskData['purpose'],
              order: weeklyTaskData['order'] ?? weeklyTaskOrder++,
              dailyTasks: dailyTasksForThisWeek, // Will be empty based on current Firestore save logic
            ));
          }
          
          monthlyTasks.add(MonthlyTaskHive(
            id: monthlyTaskDoc.id,
            title: monthlyTaskData['title'] ?? 'Untitled Monthly Task',
            estimatedDuration: monthlyTaskData['estimated_duration'],
            purpose: monthlyTaskData['purpose'],
            order: monthlyTaskData['order'] ?? monthlyTaskOrder++,
            weeklyTasks: weeklyTasks, // Corrected: assign list of WeeklyTaskHive
          ));
        }
        
        phases.add(PhaseHive(
          id: phaseDoc.id,
          title: phaseData['title'] ?? 'Untitled Phase',
          estimatedDuration: phaseData['estimated_duration'],
          purpose: phaseData['purpose'],
          order: phaseData['order'] ?? phaseOrder++,
          monthlyTasks: monthlyTasks,
        ));
      }

      return UserPlanHive(
        goalName: goalName,
        earnThisYear: userInputs['earnThisYear'] ?? '',
        currentSkill: userInputs['currentSkill'] ?? '',
        preferToEarnMoney: userInputs['preferToEarnMoney'] ?? '',
        note: userInputs['note'] ?? '',
        phases: phases,
        createdAt: (userInputs['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

    } catch (e) {
      print("Error fetching full plan data for '$goalName' from Firestore: $e");
      return null;
    }
  }


  Future<void> _fetchAllPlansFromFirestoreAndCache() async {
    // This method assumes _fetchGoalCollectionNamesFromFirestore has been called
    // and _myGoalCollectionNames is populated.

    if (_myGoalCollectionNames.isEmpty) {
      print("No goal names found in Firestore to fetch details for.");
      return;
    }

    // Fetch user inputs once - assuming they are stored in the main user document.
    // This part might need adjustment based on your exact Firestore structure for user inputs per goal.
    // If inputs like 'earnThisYear' are specific to each goal, they might be stored differently.
    // For now, fetching from the root user document as implied by chatWithAi.dart's save logic.
    Map<String, dynamic> commonUserInputs = {};
    try {
        DocumentSnapshot userDocSnapshot = await _firestore
            .collection('financialGoals')
            .doc(userId.uid)
            .get();
        if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
            commonUserInputs = userDocSnapshot.data() as Map<String, dynamic>;
        }
    } catch (e) {
        print("Could not fetch common user inputs: $e");
        // Decide how to handle this - perhaps proceed with empty inputs or stop.
    }


    int successfullyCachedCount = 0;
    for (String goalName in _myGoalCollectionNames) {
      print("Fetching full details for plan: $goalName");
      // Pass the relevant user inputs for this specific goalName.
      // If your 'commonUserInputs' map from financialGoals/{userId} is indeed common, pass it.
      // If each plan/{goalName} collection had its own metadata doc, you'd fetch it here.
      UserPlanHive? planToCache = await _fetchFullPlanDataFromFirestore(goalName, commonUserInputs);
      if (planToCache != null) {
        await _localDbService.saveUserPlan(planToCache);
        print("Plan '$goalName' cached to Hive.");
        successfullyCachedCount++;
      } else {
        print("Failed to fetch or convert plan '$goalName' for caching.");
      }
    }
    print("$successfullyCachedCount plans cached to Hive.");
  }

  // Modified _fetchGoalCollectionNames to integrate the caching logic
  Future<void> _fetchGoalCollectionNames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _navigationStack.clear();
      _currentItems.clear();
      _goalCollectionNames.clear();
    });

    try {
      _localUserPlans = _localDbService.getAllUserPlans();
      _goalCollectionNames = _localUserPlans.map((plan) => plan.goalName).toList();

      if (_goalCollectionNames.isEmpty) {
        print("No local plans found. Checking Firestore and attempting to cache...");
        // First, get the names of goals from Firestore
        await _fetchGoalCollectionNamesFromFirestore(); // This populates _myGoalCollectionNames

        if (_myGoalCollectionNames.isNotEmpty) {
          // If there are goal names, fetch their full data and cache them
          await _fetchAllPlansFromFirestoreAndCache();
          
          // After attempting to cache, reload from local DB
          _localUserPlans = _localDbService.getAllUserPlans();
          _goalCollectionNames = _localUserPlans.map((plan) => plan.goalName).toList();

          if (_goalCollectionNames.isNotEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Loaded ${_goalCollectionNames.length} plan(s) from cloud and cached locally."))
              );
            }
          } else {
            _errorMessage = "No plans found locally after attempting to cache from Firestore.";
          }
        } else {
          _errorMessage = "No plans found in Firestore to cache.";
        }
      }
    } catch (e) {
      print("Error in _fetchGoalCollectionNames: $e");
      _errorMessage = "An error occurred while loading plans: $e";
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchDataForCurrentLevel() async {
    if (_navigationStack.isEmpty) { //
      _fetchGoalCollectionNames(); // Reload goal names if at the top level
      return;
    }

    setState(() {
      _isLoading = true; //
      _errorMessage = null; //
      _currentItems.clear(); //
    });

    try {
      final currentLevelInfo = _navigationStack.last; //
      final goalName = _navigationStack.firstWhere((el) => el['type'] == 'goal')['id']!;
      UserPlanHive? plan = _localDbService.getUserPlan(goalName);

      if (plan == null) {
        _errorMessage = "Plan '$goalName' not found locally.";
        // Optional: Implement Firestore fallback for a specific plan here
        // If fetched from Firestore, save it to Hive: await _localDbService.saveUserPlan(fetchedPlan);
        setState(() => _isLoading = false); //
        return;
      }

      if (currentLevelInfo['type'] == 'goal') { // Display Phases
        _currentItems = plan.phases.map((phase) => {
          'id': phase.id,
          'title': phase.title,
          'purpose': phase.purpose,
          'estimated_duration': phase.estimatedDuration,
          'type': 'phase' // For _buildItemsList logic
        }).toList();
      } else if (currentLevelInfo['type'] == 'phase') { // Display Monthly Tasks
        String phaseId = currentLevelInfo['id']!;
        PhaseHive? phase = plan.phases.firstWhere((p) => p.id == phaseId);
        _currentItems = phase.monthlyTasks.map((mTask) => {
          'id': mTask.id,
          'title': mTask.title,
          'purpose': mTask.purpose,
          'estimated_duration': mTask.estimatedDuration,
          'type': 'monthlyTask' // For _buildItemsList logic
        }).toList();
      } else if (currentLevelInfo['type'] == 'monthlyTask') { // Display Weekly Tasks
          String phaseId = _navigationStack.firstWhere((el) => el['type'] == 'phase')['id']!;
          String monthlyTaskId = currentLevelInfo['id']!;
          PhaseHive? phase = plan.phases.firstWhere((p) => p.id == phaseId);
          MonthlyTaskHive? mTask = phase.monthlyTasks.firstWhere((mt) => mt.id == monthlyTaskId);
          _currentItems = mTask.weeklyTasks.map((wTask) => {
              'id': wTask.id,
              'title': wTask.title,
              'purpose': wTask.purpose,
              'estimated_duration': wTask.estimatedDuration,
              'type': 'weeklyTask' // For _buildItemsList logic
          }).toList();
      }
      // Add more levels (weekly to daily) if needed, similar to above.

      if (_currentItems.isEmpty) { //
          _errorMessage = "This level has no items."; //
      }

    } catch (e) {
      print("Error fetching items for ${_navigationStack.last['type']}: $e"); //
      _errorMessage = "Error loading data for this level: $e"; //
    }
    setState(() {
      _isLoading = false; //
    });
  }

  void _navigateToNextLevel(String type, String id, String name) {
    _navigationStack.add({'type': type, 'id': id, 'name': name});
    _fetchDataForCurrentLevel();
  }

  Future<bool> _onWillPop() async {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack.removeLast();
      });
      _fetchDataForCurrentLevel();
      return false; // デフォルトの戻る動作を無効化
    }
    return true; // スタックが空なら画面を閉じる
  }

  String _getAppBarTitle() {
    if (_navigationStack.isEmpty) {
      return '目標コレクション';
    }
    return _navigationStack.map((level) => level['name']).join(' > ');
  }

  Widget _buildGoalGrid() {
    if (_goalCollectionNames.isEmpty && _errorMessage == null) {
      return const Center(child: Text("目標が設定されていません。"));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2列表示
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 3 / 2, // タイルのアスペクト比
      ),
      itemCount: _goalCollectionNames.length,
      itemBuilder: (context, index) {
        final goalName = _goalCollectionNames[index];
        return Card(
          elevation: 4,
          child: InkWell(
            onTap: () {
              directory = '$directory/$goalName'; // 選択された目標のコレクション名を保存
              _navigateToNextLevel('goal', goalName, goalName); // type: 'goal', id: goalName (collection name), name: goalName
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  goalName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() {
    if (_currentItems.isEmpty && _errorMessage == null) {
      return const Center(child: Text("アイテムがありません。"));
    }
    return ListView.builder(
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        final itemTitle = item['title'] as String? ?? 'タイトルなし';
        final itemPurpose = item['purpose'] as String? ?? '';
        final itemDuration = item['estimated_duration'] as String? ?? '';

        // 次の階層があるかどうかを簡易的に判断 (ここではタイプに基づいて判断)
        bool hasChildren = _navigationStack.last['type'] != 'monthlyTask'; // 週次タスクより下はないと仮定

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            title: Text(itemTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (itemPurpose.isNotEmpty) Text("目的: $itemPurpose"),
                if (itemDuration.isNotEmpty) Text("期間: $itemDuration"),
              ],
            ),
            trailing: hasChildren ? const Icon(Icons.chevron_right) : null,
            onTap: () {
              if (!hasChildren) return; // 最下層なら何もしない

              final currentLevelType = _navigationStack.last['type'];
              if (currentLevelType == 'goal') { // 現在フェーズ表示中 -> 月次タスクへ
                _navigateToNextLevel('phase', item['id'], itemTitle);
              } else if (currentLevelType == 'phase') { // 現在月次タスク表示中 -> 週次タスクへ
                _navigateToNextLevel('monthlyTask', item['id'], itemTitle);
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
          centerTitle: true,
          leading: _navigationStack.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    directory = directory.split('/').sublist(0, directory.split('/').length - 1).join('/'); // 戻る際にディレクトリを更新
                    _onWillPop(); // WillPopScopeのロジックを再利用
                  },
                )
              : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                  ))
                : _navigationStack.isEmpty
                    ? _buildGoalGrid()
                    : _buildItemsList(),
      ),
    );
  }
}