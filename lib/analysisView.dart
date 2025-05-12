import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneymanager/themeColor.dart' as appTheme;

// ダミーデータ構造 (実際のFirestoreのデータ構造に合わせてください)
class ExpenseData {
  final String category;
  final double amount;

  ExpenseData({required this.category, required this.amount});
}

class AnalysisView extends StatefulWidget {
  const AnalysisView({Key? key}) : super(key: key);

  @override
  _AnalysisViewState createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, double> _categoryExpenses = {};
  bool _isLoading = true;
  int? _touchedIndex; // 円グラフのタッチされたセクションのインデックス

  // カテゴリーごとの色を定義 (アプリのテーマに合わせて調整可能)
  // ここではいくつかの基本色とテーマカラーを混ぜてみます。
  final List<Color> _categoryColors = [
    Colors.deepPurple[400]!,
    Colors.amberAccent[700]!,
    Colors.lightBlue[300]!,
    Colors.pink[300]!,
    Colors.green[400]!,
    Colors.orange[400]!,
    Colors.teal[300]!,
    Colors.red[300]!,
  ];

  @override
  void initState() {
    super.initState();
    _fetchExpensesForMonth(_selectedMonth);
  }

  Future<void> _fetchExpensesForMonth(DateTime month) async {
    setState(() {
      _isLoading = true;
      _categoryExpenses = {}; // 新しい月のデータを取得する前にリセット
    });

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      // ユーザーがログインしていない場合の処理
      print("ユーザーがログインしていません。");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支出データを取得するにはログインが必要です。')),
      );
      return;
    }

    final String monthYear = DateFormat('yyyy-MM').format(month);
    print('Fetching expenses for: userId=${user.uid}, monthYear=$monthYear');

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("expenses")
          .doc(user.uid)
          .collection(monthYear) // このコレクション名が 'monthYear' フィールドの値と一致するか確認
          .get();

      if (snapshot.docs.isEmpty) {
        print("No expense data found for $monthYear");
      } else {
        print("${snapshot.docs.length} documents found for $monthYear");
      }

      Map<String, double> expensesMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String category = data['category'] as String? ?? '不明';
        final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        expensesMap.update(category, (value) => value + amount, ifAbsent: () => amount);
      }
      _categoryExpenses = expensesMap;

    } catch (e) {
      print("Error fetching expenses: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支出データの取得中にエラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthDelta, 1);
      _fetchExpensesForMonth(_selectedMonth);
    });
  }

  List<PieChartSectionData> _generatePieChartSections() {
    if (_categoryExpenses.isEmpty) {
      return [];
    }

    final List<PieChartSectionData> sections = [];
    double totalAmount = _categoryExpenses.values.fold(0, (sum, item) => sum + item);
    int colorIndex = 0;

    _categoryExpenses.forEach((category, amount) {
      final isTouched = sections.length == _touchedIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 100.0 : 80.0;
      final double percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0;

      sections.add(
        PieChartSectionData(
          color: _categoryColors[colorIndex % _categoryColors.length],
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%', // カテゴリー名も表示したい場合は調整
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white, // テーマに合わせて調整
            shadows: [ const Shadow(color: Colors.black26, blurRadius: 2)],
          ),
          // titlePositionPercentageOffset: 0.55, // タイトルの位置調整
        ),
      );
      colorIndex++;
    });
    return sections;
  }

  Widget _buildLegend() {
    if (_categoryExpenses.isEmpty) {
      return const SizedBox.shrink();
    }
    int colorIndex = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _categoryExpenses.entries.map((entry) {
        final color = _categoryColors[colorIndex % _categoryColors.length];
        colorIndex++;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.rectangle, // または BoxShape.circle
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'RM ${entry.value.toStringAsFixed(0)}', // 金額フォーマットは適宜調整
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAmount = _categoryExpenses.values.fold(0.0, (sum, item) => sum + item);

    return Scaffold(
      backgroundColor: appTheme.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow for a flatter look initially
        flexibleSpace: Container( // Use flexibleSpace for gradient or custom background
          decoration: BoxDecoration(
            color: appTheme.theme.shiokuriBlue,
            borderRadius: BorderRadius.only(
                 bottomRight: Radius.circular(30), // Adjusted radius
                 bottomLeft: Radius.circular(30)
            )
          ),
        ),
        title: Text(
          "Analysis",
          style: appTheme.theme.normal.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // --- 月選択UI ---
            Row(
              children:[
                Icon(Icons.pie_chart, color: Colors.orange, size: 30),
                Text(' Total Expenses: RM ${totalAmount.toStringAsFixed(0)}',
                style: appTheme.theme.title,
              ),
            ]),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.chevron_left, color: appTheme.theme.foregroundColor, size: 30),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('yyyy-M').format(_selectedMonth),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: appTheme.theme.foregroundColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: appTheme.theme.foregroundColor, size: 30),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 28),
            

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categoryExpenses.isEmpty
                      ? Center(
                          child: Text(
                            'No data available for this month',
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        _touchedIndex = -1;
                                        return;
                                      }
                                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                borderData: FlBorderData(show: false), // 枠線なし
                                sectionsSpace: 2, // セクション間のスペース
                                centerSpaceRadius: 60, // ドーナツ型にする場合は調整 (0で通常の円)
                                // centerSpaceColor: theme.scaffoldBackgroundColor, // 中央の背景色
                                sections: _generatePieChartSections(),
                                // チャートの中央に合計金額を表示
                                // centerSpaceBuilder: (context, widget, _, __) {
                                //   return Column(
                                //     mainAxisAlignment: MainAxisAlignment.center,
                                //     children: [
                                //       Text(
                                //         '合計',
                                //         style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                //       ),
                                //       Text(
                                //         '¥${totalAmount.toStringAsFixed(0)}',
                                //         style: theme.textTheme.headlineSmall?.copyWith(
                                //           fontWeight: FontWeight.bold,
                                //           color: theme.colorScheme.primary,
                                //         ),
                                //       ),
                                //     ],
                                //   );
                                // },
                              ),
                              swapAnimationDuration: const Duration(milliseconds: 250), // アニメーション時間
                              swapAnimationCurve: Curves.easeInOut, // アニメーションカーブ
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            children:[
                              Text(
                            textAlign:  TextAlign.start,
                            "category breakdown",
                            style: appTheme.theme.subtitle,
                          ),
                          ]),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: _categoryExpenses.isEmpty
                                    ? const Center(child: Text("データがありません"))
                                    : ListView(
                                      children: [_buildLegend()], // ListViewに変更してスクロール可能に
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}