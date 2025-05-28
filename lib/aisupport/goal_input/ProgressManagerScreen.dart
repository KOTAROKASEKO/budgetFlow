import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for Firestore interactions if any remain
import 'package:moneymanager/aisupport/Database/localDatabase.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/models/daily_task_hive.dart';
import 'package:moneymanager/aisupport/models/monthly_task_hive.dart';
import 'package:moneymanager/aisupport/models/phase_hive.dart';
import 'package:moneymanager/aisupport/models/weekly_task_hive.dart';
import 'package:moneymanager/uid/uid.dart'; // Assuming this is for user ID, keep if needed
import 'package:moneymanager/aisupport/goal_input/chatWithAi.dart'; // For "Bring to Chat"

// Enum to represent menu actions
enum _ItemMenuAction { edit, delete, bringToChat }

class ProgressManagerScreen extends StatefulWidget {
  const ProgressManagerScreen({super.key});

  @override
  _ProgressManagerScreenState createState() => _ProgressManagerScreenState();
}

class _ProgressManagerScreenState extends State<ProgressManagerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  List<UserPlanHive> _localUserPlans = [];

  bool _isLoading = true;
  String? _errorMessage;
  // String directory=''; // Not used in the provided snippet for these features

  List<String> _goalCollectionNames = [];
  List<Map<String, dynamic>> _currentItems = [];
  List<Map<String, String>> _navigationStack = [];

  List<String> _myGoalCollectionNames = [];


  @override
  void initState() {
    super.initState();
    _fetchGoalCollectionNames();
  }

  Future<void> _fetchGoalCollectionNamesFromFirestore() async { //
    setState(() {
      // _isLoading = true; // Managed by the caller
    });
    try {
      DocumentSnapshot userDocSnapshot = await _firestore
          .collection('financialGoals')
          .doc(userId.uid) //
          .get();

      if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
        final data = userDocSnapshot.data() as Map<String, dynamic>;
        _myGoalCollectionNames = List<String>.from(data['goalNameList'] ?? []); //
      } else {
        _myGoalCollectionNames = [];
      }
    } catch (e) {
      print("Error fetching goal collection names from Firestore: $e"); //
      _myGoalCollectionNames = [];
      // _errorMessage = "Error fetching goal names from Firestore."; // Managed by caller
    }
  }

  Future<UserPlanHive?> _fetchFullPlanDataFromFirestore(String goalName, Map<String, dynamic> userInputs) async { //
    List<PhaseHive> phases = [];
    try {
      QuerySnapshot phaseSnapshot = await _firestore
          .collection('financialGoals')
          .doc(userId.uid) //
          .collection(goalName)
          .orderBy('order') //
          .get();

      int phaseOrder = 0;
      for (var phaseDoc in phaseSnapshot.docs) {
        Map<String, dynamic> phaseData = phaseDoc.data() as Map<String, dynamic>;
        List<MonthlyTaskHive> monthlyTasks = [];

        QuerySnapshot monthlyTaskSnapshot = await phaseDoc.reference //
            .collection('monthlyTasks') //
            .orderBy('order') //
            .get();
        
        int monthlyTaskOrder = 0;
        for (var monthlyTaskDoc in monthlyTaskSnapshot.docs) {
          Map<String, dynamic> monthlyTaskData = monthlyTaskDoc.data() as Map<String, dynamic>;
          List<WeeklyTaskHive> weeklyTasks = [];

          QuerySnapshot weeklyTaskSnapshot = await monthlyTaskDoc.reference //
              .collection('weeklyTasks') //
              .orderBy('order') //
              .get();

          int weeklyTaskOrder = 0;
          for (var weeklyTaskDoc in weeklyTaskSnapshot.docs) {
            Map<String, dynamic> weeklyTaskData = weeklyTaskDoc.data() as Map<String, dynamic>;
            List<DailyTaskHive> dailyTasksForThisWeek = []; 
            // Firestore save logic in ChatWithAiScreen does not save daily tasks under weekly tasks directly.
            // If it did, they would be fetched here.

            weeklyTasks.add(WeeklyTaskHive( //
              id: weeklyTaskDoc.id, //
              title: weeklyTaskData['title'] ?? 'Untitled Weekly Task', //
              estimatedDuration: weeklyTaskData['estimated_duration'], //
              purpose: weeklyTaskData['purpose'], //
              order: weeklyTaskData['order'] ?? weeklyTaskOrder++, //
              dailyTasks: dailyTasksForThisWeek, //
            ));
          }
          
          monthlyTasks.add(MonthlyTaskHive( //
            id: monthlyTaskDoc.id, //
            title: monthlyTaskData['title'] ?? 'Untitled Monthly Task', //
            estimatedDuration: monthlyTaskData['estimated_duration'], //
            purpose: monthlyTaskData['purpose'], //
            order: monthlyTaskData['order'] ?? monthlyTaskOrder++, //
            weeklyTasks: weeklyTasks, //
          ));
        }
        
        phases.add(PhaseHive( //
          id: phaseDoc.id, //
          title: phaseData['title'] ?? 'Untitled Phase', //
          estimatedDuration: phaseData['estimated_duration'], //
          purpose: phaseData['purpose'], //
          order: phaseData['order'] ?? phaseOrder++, //
          monthlyTasks: monthlyTasks, //
        ));
      }

      return UserPlanHive( //
        goalName: goalName, //
        earnThisYear: userInputs['earnThisYear'] ?? '', //
        currentSkill: userInputs['currentSkill'] ?? '', //
        preferToEarnMoney: userInputs['preferToEarnMoney'] ?? '', //
        note: userInputs['note'] ?? '', //
        phases: phases, //
        createdAt: (userInputs['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), //
      );

    } catch (e) {
      print("Error fetching full plan data for '$goalName' from Firestore: $e"); //
      return null;
    }
  }

  Future<void> _fetchAllPlansFromFirestoreAndCache() async { //
    if (_myGoalCollectionNames.isEmpty) {
      print("No goal names found in Firestore to fetch details for."); //
      return;
    }
    Map<String, dynamic> commonUserInputs = {}; //
    try {
        DocumentSnapshot userDocSnapshot = await _firestore
            .collection('financialGoals')
            .doc(userId.uid) //
            .get();
        if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
            commonUserInputs = userDocSnapshot.data() as Map<String, dynamic>; //
        }
    } catch (e) {
        print("Could not fetch common user inputs: $e"); //
    }

    int successfullyCachedCount = 0;
    for (String goalName in _myGoalCollectionNames) {
      UserPlanHive? planToCache = await _fetchFullPlanDataFromFirestore(goalName, commonUserInputs); //
      if (planToCache != null) {
        await _localDbService.saveUserPlan(planToCache); //
        successfullyCachedCount++;
      }
    }
    print("$successfullyCachedCount plans cached to Hive."); //
  }


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
      _goalCollectionNames = _localUserPlans.map((plan) => plan.goalName).toList(); //

      if (_goalCollectionNames.isEmpty) { //
        await _fetchGoalCollectionNamesFromFirestore(); //

        if (_myGoalCollectionNames.isNotEmpty) { //
          await _fetchAllPlansFromFirestoreAndCache(); //
          
          _localUserPlans = _localDbService.getAllUserPlans(); //
          _goalCollectionNames = _localUserPlans.map((plan) => plan.goalName).toList(); //

          if (_goalCollectionNames.isNotEmpty && mounted) { //
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Loaded ${_goalCollectionNames.length} plan(s) from cloud and cached locally.")) //
              );
          } else {
            _errorMessage = "No plans found locally after attempting to cache from Firestore."; //
          }
        } else {
          _errorMessage = "No plans found in Firestore to cache."; //
        }
      }
    } catch (e) {
      print("Error in _fetchGoalCollectionNames: $e"); //
      _errorMessage = "An error occurred while loading plans: $e"; //
    }
    if(mounted){
        setState(() {
        _isLoading = false; //
        });
    }
  }

  Future<void> _fetchDataForCurrentLevel() async {

    if (_navigationStack.isEmpty) {
      _fetchGoalCollectionNames();
      return;
    }

    if (!mounted) return; // Prevent setState calls if widget is disposed
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentItems.clear();
    });

    try {
      final currentLevelInfo = _navigationStack.last;
      final String goalName = _getGoalNameFromStack()!;
      UserPlanHive? plan = _localDbService.getUserPlan(goalName);

      if (plan == null) {
        _errorMessage = "Plan '$goalName' not found locally.";
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (currentLevelInfo['type'] == 'goal') {
        _currentItems = plan.phases.map((phase) => {
          'id': phase.id,
          'title': phase.title,
          'purpose': phase.purpose,
          'estimated_duration': phase.estimatedDuration,
          'type': 'phase',
          'parentId': goalName,
        }).toList();
      } else if (currentLevelInfo['type'] == 'phase') {
        String phaseId = currentLevelInfo['id']!;
        PhaseHive? phase = plan.phases.firstWhere((p) => p.id == phaseId, orElse: () {
          throw Exception("Phase with id $phaseId not found in plan $goalName");
        });
        _currentItems = phase.monthlyTasks.map((mTask) => {
          'id': mTask.id,
          'title': mTask.title,
          'purpose': mTask.purpose,
          'estimated_duration': mTask.estimatedDuration,
          'type': 'monthlyTask',
          'parentId': phaseId,
        }).toList();
      } else if (currentLevelInfo['type'] == 'monthlyTask') {
        String phaseId = _navigationStack.firstWhere((el) => el['type'] == 'phase')['id']!;
        String monthlyTaskId = currentLevelInfo['id']!;
        PhaseHive? phase = plan.phases.firstWhere((p) => p.id == phaseId, orElse: () {
          throw Exception("Phase with id $phaseId not found");
        });
        MonthlyTaskHive? mTask = phase.monthlyTasks.firstWhere((mt) => mt.id == monthlyTaskId, orElse: () {
          throw Exception("MonthlyTask with id $monthlyTaskId not found");
        });
        _currentItems = mTask.weeklyTasks.map((wTask) => {
          'id': wTask.id,
          'title': wTask.title,
          'purpose': wTask.purpose,
          'estimated_duration': wTask.estimatedDuration,
          'type': 'weeklyTask',
          'parentId': monthlyTaskId,
        }).toList();
      } else if (currentLevelInfo['type'] == 'weeklyTask') {
        String phaseId = _navigationStack.firstWhere((el) => el['type'] == 'phase')['id']!;
        String monthlyTaskId = _navigationStack.firstWhere((el) => el['type'] == 'monthlyTask')['id']!;
        String weeklyTaskId = currentLevelInfo['id']!;

        PhaseHive? phase = plan.phases.firstWhere((p) => p.id == phaseId, orElse: () {
          throw Exception("Phase with id $phaseId not found");
        });
        MonthlyTaskHive? mTask = phase.monthlyTasks.firstWhere((mt) => mt.id == monthlyTaskId, orElse: () {
          throw Exception("MonthlyTask with id $monthlyTaskId not found");
        });
        WeeklyTaskHive? wTask = mTask.weeklyTasks.firstWhere((wt) => wt.id == weeklyTaskId, orElse: () {
          throw Exception("WeeklyTask with id $weeklyTaskId not found");
        });

        _currentItems = wTask.dailyTasks.map((dTask) => {
          'id': dTask.id,
          'title': dTask.title,
          'purpose': dTask.purpose ?? '', // DailyTaskHiveのpurposeはnullableなので対応
          'estimated_duration': dTask.estimatedDuration ?? '', // DailyTaskHiveのestimatedDurationはnullableなので対応
          'type': 'dailyTask', // タイプをdailyTaskに設定
          'dueDate': dTask.dueDate.toIso8601String(), // dueDateも表示や編集のために含めることを検討
          'status': dTask.status, // statusも表示や編集のために含めることを検討
          'parentId': weeklyTaskId,
        }).toList();
      }

      if (_currentItems.isEmpty) {
        _errorMessage = "This level has no items.";
      }
    } catch (e) {
      print("Error fetching items for ${_navigationStack.isNotEmpty ? _navigationStack.last['type'] : 'goals'}: $e");
      _errorMessage = "Error loading data for this level: $e";
    }
    if (mounted) { // mountedチェックを追加
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToNextLevel(String type, String id, String name) { //
    // directory = '$directory/$name'; // Not used for these features
    _navigationStack.add({'type': type, 'id': id, 'name': name}); //
    _fetchDataForCurrentLevel(); //
  }

  Future<bool> _onWillPop() async { //
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack.removeLast(); //
        // directory = directory.split('/').sublist(0, directory.split('/').length - 1).join('/'); // Not used
      });
      _fetchDataForCurrentLevel(); //
      return false;
    }
    return true;
  }

  String _getAppBarTitle() { //
    if (_navigationStack.isEmpty) {
      return 'Financial Goal Plans'; //
    }
    return _navigationStack.map((level) => level['name']).join(' > '); //
  }

  String? _getGoalNameFromStack() { // Helper to get current goal name
      if (_navigationStack.isEmpty) return null;
      final goalLevel = _navigationStack.firstWhere((el) => el['type'] == 'goal', orElse: () => {'id': ''});
      return goalLevel['id'];
  }


  // --- New Methods for Edit, Delete, Bring to Chat ---

  void _showItemOptionsMenu(BuildContext context, Map<String, dynamic> item, Offset globalPosition) {


    showMenu<_ItemMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
          MediaQuery.of(context).size.width - globalPosition.dx,
          MediaQuery.of(context).size.height - globalPosition.dy),
      items: [
        const PopupMenuItem(
          value: _ItemMenuAction.edit,
          child: ListTile(leading: Icon(Icons.edit), title: Text('Edit')),
        ),
        const PopupMenuItem(
          value: _ItemMenuAction.delete,
          child: ListTile(leading: Icon(Icons.delete), title: Text('Delete')),
        ),
        const PopupMenuItem(
          value: _ItemMenuAction.bringToChat,
          child: ListTile(leading: Icon(Icons.chat_bubble_outline), title: Text('Bring to Chat')),
        ),
      ],
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case _ItemMenuAction.edit:
          _handleEditItem(item);
          break;
        case _ItemMenuAction.delete:
          _handleDeleteItem(item);
          break;
        case _ItemMenuAction.bringToChat:
          _handleBringToChat(item);
          break;
      }
    });
  }

  Future<void> _handleDeleteItem(Map<String, dynamic> item) async {
    final String itemType = item['type'] as String;
    final String itemId = item['id'] as String; // This is goalName for 'goal' type
    final String itemTitle = item['title'] as String? ?? 'Item';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $itemTitle?'),
        content: Text('Are you sure you want to delete "$itemTitle"${itemType != 'goal' ? "" : " and all its phases and tasks"}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      if (itemType == 'goal') {
        await _localDbService.deleteUserPlan(itemId); // itemId is goalName here
        _fetchGoalCollectionNames(); // Refresh goal list
      } else {
        String? goalName = _getGoalNameFromStack();
        if (goalName == null) throw Exception("Goal name not found in navigation stack for deletion.");
        UserPlanHive? plan = _localDbService.getUserPlan(goalName);
        if (plan == null) throw Exception("Plan $goalName not found for deletion of sub-item.");

        bool modified = false;
        if (itemType == 'phase') {
          plan.phases.removeWhere((phase) => phase.id == itemId);
          modified = true;
        } else if (itemType == 'monthlyTask') {
          for (var phase in plan.phases) {
            final originalLength = phase.monthlyTasks.length;
            phase.monthlyTasks.removeWhere((mTask) => mTask.id == itemId);
            if (phase.monthlyTasks.length < originalLength) {
              modified = true;
              break;
            }
          }
        } else if (itemType == 'weeklyTask') {
          for (var phase in plan.phases) {
            for (var mTask in phase.monthlyTasks) {
              final originalLength = mTask.weeklyTasks.length;
              mTask.weeklyTasks.removeWhere((wTask) => wTask.id == itemId);
              if (mTask.weeklyTasks.length < originalLength) {
                modified = true;
                break;
              }
            }
            if (modified) break;
          }
        }
        // Daily tasks are not directly managed at this level in _currentItems based on current structure

        if (modified) {
          await _localDbService.saveUserPlan(plan);
        }
        _fetchDataForCurrentLevel(); // Refresh current view
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$itemTitle" deleted successfully.')));
      }
    } catch (e) {
      print("Error deleting item: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting "$itemTitle": $e'), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEditItem(Map<String, dynamic> item) async {
    final String itemType = item['type'] as String;
    final String itemId = item['id'] as String; 

    if (itemType == 'goal') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Editing the top-level goal name is not directly supported here. You can manage goal names by creating new plans or by more advanced data management if needed.')));
        return;
    }
    
    String? goalName = _getGoalNameFromStack();
    if (goalName == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not identify the current goal.')));
        return;
    }
    UserPlanHive? plan = _localDbService.getUserPlan(goalName);
    if (plan == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Plan "$goalName" not found.')));
        return;
    }

    dynamic targetItemObject; // This remains dynamic

    if (itemType == 'phase') {
        for (var p in plan.phases) {
            if (p.id == itemId) {
                targetItemObject = p;
                break;
            }
        }
    } else if (itemType == 'monthlyTask') {
        for (var phase in plan.phases) {
            for (var mt in phase.monthlyTasks) {
                if (mt.id == itemId) {
                    targetItemObject = mt;
                    break;
                }
            }
            if (targetItemObject != null) break;
        }
    } else if (itemType == 'weeklyTask') {
         for (var phase in plan.phases) {
            for (var mTask in phase.monthlyTasks) {
                for (var wt in mTask.weeklyTasks) {
                    if (wt.id == itemId) {
                        targetItemObject = wt;
                        break;
                    }
                }
                if (targetItemObject != null) break;
            }
            if (targetItemObject != null) break;
        }
    }

    if (targetItemObject == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Item not found for editing.')));
        return;
    }

    // The rest of the _handleEditItem method remains the same...
    final TextEditingController titleController = TextEditingController(text: targetItemObject.title);
    final TextEditingController purposeController = TextEditingController(text: targetItemObject.purpose);
    final TextEditingController durationController = TextEditingController(text: targetItemObject.estimatedDuration);

    final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text('Edit ${item['title']}'),
            content: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                        TextField(controller: purposeController, decoration: const InputDecoration(labelText: 'Purpose'), maxLines: 3),
                        TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Estimated Duration')),
                    ],
                ),
            ),
            actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                        Navigator.of(ctx).pop({
                            'title': titleController.text,
                            'purpose': purposeController.text,
                            'duration': durationController.text,
                        });
                    },
                    child: const Text('Save')),
            ],
        ),
    );

    if (result != null) {
        setState(() => _isLoading = true);
        try {
            targetItemObject.title = result['title']!;
            targetItemObject.purpose = result['purpose']!;
            targetItemObject.estimatedDuration = result['duration']!;

            await _localDbService.saveUserPlan(plan);
            _fetchDataForCurrentLevel(); // Refresh
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${targetItemObject.title}" updated.')));
            }
        } catch (e) {
            print("Error updating item: $e");
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating item: $e'), backgroundColor: Colors.red));
            }
        } finally {
            if(mounted) setState(() => _isLoading = false);
        }
    }
  }
  
  Future<void> _handleBringToChat(Map<String, dynamic> item) async {
    final String itemType = item['type'] as String;
    final String itemId = item['id'] as String; // This is goalName for 'goal' type

    String? goalName = (itemType == 'goal') ? itemId : _getGoalNameFromStack();

    if (goalName == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not identify the goal plan.')));
        return;
    }

    UserPlanHive? plan = _localDbService.getUserPlan(goalName);
    if (plan == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Plan "$goalName" not found.')));
        return;
    }
    
    // For simplicity, we pass the whole plan and let ChatWithAIScreen handle focusing if needed.
    // Or, we could pass specific item details.
    // For now, passing the whole plan along with original inputs.
    // A more advanced implementation might pass only a section of the plan.

    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ChatWithAIScreen(
            earnThisYear: plan.earnThisYear, //
            currentSkill: plan.currentSkill, //
            preferToEarnMoney: plan.preferToEarnMoney, //
            note: plan.note, //
            existingPlanForRefinement: plan, // Pass the whole plan
            // Optionally pass itemType and itemId if ChatWithAI needs to focus:
            // focusItemType: itemType, 
            // focusItemId: itemId,
        ),
    ));
  }

  Widget _buildGoalGrid() { //
    if (_isLoading && _goalCollectionNames.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_goalCollectionNames.isEmpty && _errorMessage == null) { //
      return const Center(child: Text("No financial plans set up yet. Create one with the AI planner!")); //
    }
     if (_errorMessage != null && _goalCollectionNames.isEmpty) {
        return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0), //
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( //
        crossAxisCount: 2, //
        crossAxisSpacing: 16.0, //
        mainAxisSpacing: 16.0, //
        childAspectRatio: 3 / 2, //
      ),
      itemCount: _goalCollectionNames.length, //
      itemBuilder: (context, index) {
        final goalName = _goalCollectionNames[index]; //
        final itemData = {'id': goalName, 'title': goalName, 'type': 'goal'};

        return GestureDetector(
          onLongPressStart: (details) {
             _showItemOptionsMenu(context, itemData, details.globalPosition);
          },
          child: Card( //
            elevation: 4, //
            child: InkWell( //
              onTap: () { //
                _navigateToNextLevel('goal', goalName, goalName); //
              },
              child: Center( //
                child: Padding( //
                  padding: const EdgeInsets.all(8.0), //
                  child: Text( //
                    goalName, //
                    textAlign: TextAlign.center, //
                    style: Theme.of(context).textTheme.titleMedium, //
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() { //
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_currentItems.isEmpty && _errorMessage == null) { //
      return const Center(child: Text("No items at this level.")); //
    }
    if (_errorMessage != null && _currentItems.isEmpty) {
       return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ));
    }

    return ListView.builder( //
      itemCount: _currentItems.length, //
      itemBuilder: (context, index) {
        final item = _currentItems[index]; //
        final itemTitle = item['title'] as String? ?? 'No Title'; //
        final itemPurpose = item['purpose'] as String? ?? ''; //
        final itemDuration = item['estimated_duration'] as String? ?? ''; //
        final itemType = item['type'] as String;

        bool hasChildren = itemType != 'dailyTask';  // Assuming weekly tasks are the lowest level displayed here.
                                                        // Original logic: _navigationStack.last['type'] != 'monthlyTask' which seems to be one level off.
                                                        // Correcting based on typical hierarchy: Goal -> Phase -> Monthly -> Weekly. Daily not shown in this list view.

        return GestureDetector(
          onLongPressStart: (details) {
            _showItemOptionsMenu(context, item, details.globalPosition);
          },
          child: Card( //
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), //
            elevation: 2, //
            child: ListTile( //
              title: Text(itemTitle, style: const TextStyle(fontWeight: FontWeight.bold)), //
              subtitle: Column( //
                crossAxisAlignment: CrossAxisAlignment.start, //
                children: [
                  if (itemPurpose.isNotEmpty) Text("Purpose: $itemPurpose"), //
                  if (itemDuration.isNotEmpty) Text("Duration: $itemDuration"), //
                ],
              ),
              trailing: hasChildren ? const Icon(Icons.chevron_right) : null, //
              onTap: () { //
                if (!hasChildren) return;

                final currentLevelType = _navigationStack.last['type']; //
                if (currentLevelType == 'goal') { //
                  _navigateToNextLevel('phase', item['id'], itemTitle); //
                } else if (currentLevelType == 'phase') { //
                  _navigateToNextLevel('monthlyTask', item['id'], itemTitle); //
                } else if (currentLevelType == 'monthlyTask') { // New logic for weekly tasks
                   _navigateToNextLevel('weeklyTask', item['id'], itemTitle); 
                } else if (currentLevelType == 'weeklyTask') { // ★★★ 修正箇所 ★★★
                _navigateToNextLevel('dailyTask', item['id'], itemTitle); // 次のレベルは 'dailyTask'
              }
                // weeklyTask is the last level in this view, so no further navigation on tap.
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope( //
      onWillPop: _onWillPop, //
      child: Scaffold(
        appBar: AppBar( //
          title: Text(_getAppBarTitle()), //
          centerTitle: true, //
          leading: _navigationStack.isNotEmpty //
              ? IconButton( //
                  icon: const Icon(Icons.arrow_back), //
                  onPressed: () { //
                    _onWillPop(); //
                  },
                )
              : null,
        ),
        body: _isLoading && (_navigationStack.isEmpty ? _goalCollectionNames.isEmpty : _currentItems.isEmpty)
            ? const Center(child: CircularProgressIndicator()) //
            : _errorMessage != null && (_navigationStack.isEmpty ? _goalCollectionNames.isEmpty : _currentItems.isEmpty)
                ? Center(child: Padding( //
                    padding: const EdgeInsets.all(16.0), //
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center), //
                  ))
                : _navigationStack.isEmpty //
                    ? _buildGoalGrid() //
                    : _buildItemsList(), //
      ),
    );
  }
}