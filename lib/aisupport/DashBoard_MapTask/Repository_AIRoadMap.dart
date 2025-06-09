import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:moneymanager/security/uid.dart'; // Assuming userId is available here

class AIFinanceRepository {
  final PlanRepository _localPlanRepository;
  final FirebaseFirestore _firestore;

  AIFinanceRepository({
    required PlanRepository localPlanRepository,
    FirebaseFirestore? firestore,
  })  : _localPlanRepository = localPlanRepository,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches the primary goal tasks.
  /// It first checks the local database. If empty, it tries to fetch from a remote source (Firestore).
  Future<List<TaskHiveModel>> syncAndGetGoalTasks() async {
    // 1. Try to get goals from the local Hive database first
    List<TaskHiveModel> localGoals = await _localPlanRepository.getGoalTasks();

    if (localGoals.isNotEmpty) {
      return localGoals;
    }

    // 2. If local is empty, fetch from remote (example using Firestore)
    // This is a placeholder for your actual remote fetching logic.
    print("Local database is empty. Attempting to fetch from remote...");
    try {
      final remoteGoals = await _fetchGoalsFromFirestore(userId.uid);

      // 3. If remote goals are found, save them to the local database for future offline access
      if (remoteGoals.isNotEmpty) {
        print("Found ${remoteGoals.length} goals remotely. Saving to local DB.");
        await _localPlanRepository.saveAllTasks(remoteGoals);
        // We could also fetch all sub-tasks here and save them.
        return remoteGoals;
      }
    } catch (e) {
      print("Failed to fetch or sync from remote source: $e");
      // Handle error appropriately, maybe return empty list or throw
    }

    return []; // Return empty if nothing found locally or remotely
  }

  /// EXAMPLE: Fetches goal data from Firestore.
  /// You would need to implement the logic to convert Firestore documents to TaskHiveModel.
  Future<List<TaskHiveModel>> _fetchGoalsFromFirestore(String userId) async {
    // This is an example and assumes a 'financialGoals' collection.
    // The structure of your Firestore data would determine the actual implementation.
    final QuerySnapshot snapshot = await _firestore
        .collection('financialGoals')
        .doc(userId)
        .collection('goals') // Assuming goals are stored in a sub-collection
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    // This mapping is purely illustrative. You must adapt it to your data model.
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return TaskHiveModel(
        id: doc.id,
        title: data['title'] ?? 'Untitled Goal',
        duration: data['duration'] ?? 'N/A',
        taskLevel: TaskLevelName.Goal,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        order: 0,
        // ... map other fields
      );
    }).toList();
  }

  // You can delegate other methods directly to the local repository if no remote logic is needed
  Future<List<TaskHiveModel>> getSubTasks(String parentId) {
    return _localPlanRepository.getSubTasks(parentId);
  }

  Future<void> updateTask(TaskHiveModel task) {
    return _localPlanRepository.updateTask(task);
  }
}