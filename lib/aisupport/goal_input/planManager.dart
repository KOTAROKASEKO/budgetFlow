import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // TODO: 実際のユーザーIDを取得する処理
    // final user = FirebaseAuth.instance.currentUser;
    // if (user != null) {
    //   _userId = user.uid;
    // } else {
    //   // ユーザーがログインしていない場合の処理
    //   _errorMessage = "ユーザーがログインしていません。";
    //   _isLoading = false;
    //   return;
    // }
    _fetchGoalCollectionNames();
  }

  // ... (クラスの他の部分は変更なし)
  List<String> _myGoalCollectionNames = []; // 変数名を明確化

  // ... initState() など ...

  Future<void> _fetchGoalCollectionNames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _navigationStack.clear();
      _currentItems.clear();    // 表示アイテムもクリア
    });
    try {
      DocumentSnapshot userDocSnapshot = await _firestore
          .collection('financialGoals')
          .doc(userId.uid)
          .get();

      if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
        final data = userDocSnapshot.data() as Map<String, dynamic>;
        // ★★★ Firestore ドキュメントの実際のフィールド名に合わせてください ★★★
        _myGoalCollectionNames = List<String>.from(data['goalNameList'] ?? []);
        _goalCollectionNames = _myGoalCollectionNames; // 表示用にセット
        if (_myGoalCollectionNames.isEmpty) {
          _errorMessage = "表示できる目標がありません。プランを作成してください。";
        }
      } else {
        _errorMessage = "ユーザーデータが見つかりません。";
      }
    } catch (e) {
      print("Error fetching goal collections: $e");
      _errorMessage = "目標の読み込み中にエラーが発生しました。";
    }
    setState(() {
      _isLoading = false;
    });
  }
  Future<void> _fetchDataForCurrentLevel() async {
    if (_navigationStack.isEmpty) {
      _fetchGoalCollectionNames();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentItems.clear();
    });

    try {
      final currentLevelInfo = _navigationStack.last;
      QuerySnapshot snapshot;

      if (currentLevelInfo['type'] == 'goal') { // フェーズを取得
        String goalCollectionName = currentLevelInfo['id']!;
        snapshot = await _firestore
            .collection('financialGoals')
            .doc(userId.uid) // _userId を使用
            .collection(goalCollectionName)
            .orderBy('order') // 'order' フィールドで並び替え
            .get();
      } else if (currentLevelInfo['type'] == 'phase') { // 月次タスクを取得
        String goalCollectionName = _navigationStack.firstWhere((el) => el['type'] == 'goal')['id']!;
        String phaseId = currentLevelInfo['id']!;
        snapshot = await _firestore
            .collection('financialGoals')
            .doc(userId.uid) // _userId を使用
            .collection(goalCollectionName)
            .doc(phaseId)
            .collection('monthlyTasks')
            .orderBy('order')
            .get();
      } else if (currentLevelInfo['type'] == 'monthlyTask') { // 週次タスクを取得
        String goalCollectionName = _navigationStack.firstWhere((el) => el['type'] == 'goal')['id']!;
        String phaseId = _navigationStack.firstWhere((el) => el['type'] == 'phase')['id']!;
        String monthlyTaskId = currentLevelInfo['id']!;
        snapshot = await _firestore
            .collection('financialGoals')
            .doc(userId.uid) // _userId を使用
            .collection(goalCollectionName)
            .doc(phaseId)
            .collection('monthlyTasks')
            .doc(monthlyTaskId)
            .collection('weeklyTasks')
            .orderBy('order')
            .get();
      } else {
        _errorMessage = "不明な階層です。";
        setState(() => _isLoading = false);
        return;
      }
      _currentItems = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
      if (_currentItems.isEmpty) {
          _errorMessage = "この階層にはアイテムがありません。";
      }

    } catch (e) {
      print("Error fetching items for ${ _navigationStack.last['type']}: $e");
      _errorMessage = "データの読み込み中にエラーが発生しました。";
    }
    setState(() {
      _isLoading = false;
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