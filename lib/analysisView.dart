import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneymanager/themeColor.dart' as appTheme; // themeColor.dart が存在すると仮定

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

  // 新しいグラフ用の状態変数
  double _initialSavingAmount = 0.0;
  List<FlSpot> _savingHistorySpots = [];
  double? _minTimestampX;
  double? _maxTimestampX;

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
    _fetchDataForMonth(_selectedMonth); 
  }

  Future<void> _fetchDataForMonth(DateTime month) async {
    setState(() {
      _isLoading = true;
      _categoryExpenses = {};
      _savingHistorySpots = []; // 新しいグラフ用データをリセット
      _initialSavingAmount = 0.0;
      _minTimestampX = null;
      _maxTimestampX = null;
    });

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      print("user didn t login");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to log in to get data')),
        );
      }
      return;
    }

    final String monthYear = DateFormat('yyyy-MM').format(month);
    print('Fetching data for: userId=${user.uid}, monthYear=$monthYear');

    try {
      // 1. Fetch initial saving amount
      // 'users' コレクション名は実際の Firestore の構造に合わせてください
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('saving').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _initialSavingAmount = (userData['saving'] as num?)?.toDouble() ?? 0.0;
        print("Initial saving amount: $_initialSavingAmount");
      } else {
        _initialSavingAmount = 0.0;
        print("Saving data not found for user ${user.uid}. Defaulting to 0.");
      }

      // 2. Fetch expenses for the month, sorted by timestamp
      final QuerySnapshot expenseSnapshot = await FirebaseFirestore.instance
          .collection("expenses")
          .doc(user.uid)
          .collection(monthYear)
          .orderBy("timestamp", descending: false) // timestampで昇順ソート
          .get();

      if (expenseSnapshot.docs.isEmpty) {
        print("No expense data found for $monthYear");
      } else {
        print("${expenseSnapshot.docs.length} expense documents found for $monthYear");
      }

      Map<String, double> tempCategoryExpenses = {};
      List<Map<String, dynamic>> monthlyExpenses = [];

      for (var doc in expenseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String category = data['category'] as String? ?? '不明';
        final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final String type = data['type'] as String? ?? 'expense'; // typeフィールドを取得

        // カテゴリ別集計 (支出のみ)
        if (type == 'expense') {
          tempCategoryExpenses.update(category, (value) => value + amount, ifAbsent: () => amount);
        }
        
        // 貯金推移計算用の支出リスト (支出のみ)
        if (type == 'expense' && data.containsKey('timestamp')) {
           final Timestamp timestamp = data['timestamp'] as Timestamp;
           monthlyExpenses.add({'amount': amount, 'timestamp': timestamp});
        } else if (type == 'expense' && !data.containsKey('timestamp')) {
            print("Warning: Expense document ${doc.id} is missing timestamp.");
        }
      }
      _categoryExpenses = tempCategoryExpenses;

      // 3. Calculate saving history
      _calculateSavingHistory(monthlyExpenses, month);

    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの取得中にエラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _calculateSavingHistory(List<Map<String, dynamic>> expenses, DateTime selectedMonth) {
    List<FlSpot> spots = [];
    double currentSaving = _initialSavingAmount;

    // 月の初めのタイムスタンプ
    final firstDayOfMonthTimestamp = DateTime(selectedMonth.year, selectedMonth.month, 1).millisecondsSinceEpoch.toDouble();
    // 月の終わりのタイムスタンプ (最終日の23:59:59)
    final lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
    final lastDayOfMonthTimestamp = lastDayOfMonth.millisecondsSinceEpoch.toDouble();

    // X軸の範囲をまず月の範囲で設定
    _minTimestampX = firstDayOfMonthTimestamp;
    _maxTimestampX = lastDayOfMonthTimestamp;

    // グラフの開始点として、月の初めの初期貯金額をプロット
    spots.add(FlSpot(firstDayOfMonthTimestamp, currentSaving));

    if (expenses.isNotEmpty) {
        for (var expense in expenses) {
            currentSaving -= expense['amount'] as double;
            Timestamp ts = expense['timestamp'] as Timestamp;
            double expenseTimestamp = ts.millisecondsSinceEpoch.toDouble();
            
            // タイムスタンプが月の範囲内にあるか確認（念のため）
            // if (expenseTimestamp >= firstDayOfMonthTimestamp && expenseTimestamp <= lastDayOfMonthTimestamp) {
            spots.add(FlSpot(expenseTimestamp, currentSaving));
            // }
        }
        // 支出がある場合、X軸の範囲を実際の支出の範囲も考慮して調整する
        // ただし、月の範囲より狭くはしない
        // _minTimestampX = spots.first.x < firstDayOfMonthTimestamp ? spots.first.x : firstDayOfMonthTimestamp;
        // _maxTimestampX = spots.last.x > lastDayOfMonthTimestamp ? spots.last.x : lastDayOfMonthTimestamp;
    } else {
      // 支出がない場合でも、月の終わりにも同じ貯金額の点を打つことで、グラフに線が表示されるようにする
      // spots.add(FlSpot(lastDayOfMonthTimestamp, currentSaving)); // これだと常に水平線になるので、開始点だけでよいかも
    }


    _savingHistorySpots = spots;

    // デバッグログ
    // print("Calculated Saving History Spots: ${_savingHistorySpots.length} points");
    // _savingHistorySpots.forEach((spot) => print("Spot: x=${DateTime.fromMillisecondsSinceEpoch(spot.x.toInt())}, y=${spot.y}"));
    // print("MinX: ${DateTime.fromMillisecondsSinceEpoch(_minTimestampX!.toInt())}, MaxX: ${DateTime.fromMillisecondsSinceEpoch(_maxTimestampX!.toInt())}");
  }


  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthDelta, 1);
      _fetchDataForMonth(_selectedMonth); // 修正したメソッドを呼び出す
    });
  }

  List<PieChartSectionData> _generatePieChartSections() {
    // ... (既存のコード、変更なし)
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
          title: '${percentage.toStringAsFixed(1)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [ const Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
      );
      colorIndex++;
    });
    return sections;
  }

  Widget _buildLegend() {
    // ... (既存のコード、変更なし)
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
                  shape: BoxShape.rectangle,
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
                'RM ${entry.value.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 新しい折れ線グラフのウィジェット
  Widget _buildSavingHistoryChart() {
    if (_isLoading) { // ローディング中は何もしない（全体のローディングインジケータに任せる）
      return const SizedBox.shrink();
    }
    // 貯金データはあるが、グラフ化するほどの支出履歴がない場合
    if (_savingHistorySpots.length <= 1 && _initialSavingAmount > 0) {
        return SizedBox(
            height: 200,
            child: Center(
                child: Text(
                'Initial Saving: RM ${_initialSavingAmount.toStringAsFixed(0)}\nNo sufficient expense data this month to show trend.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
            ),
        );
    }
    // 貯金データも履歴もない場合
    if (_savingHistorySpots.isEmpty || _savingHistorySpots.length <= 1) { // 1点以下では線が引けない
        return SizedBox(
            height: 200,
            child: Center(
                child: Text(
                'No saving trend data available for this month.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
            ),
        );
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        _generateSavingHistoryChartData(),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  // 新しい折れ線グラフのデータ生成
  LineChartData _generateSavingHistoryChartData() {
    final theme = Theme.of(context);
    
    double minYValue = _initialSavingAmount;
    double maxYValue = _initialSavingAmount;

    if (_savingHistorySpots.isNotEmpty) {
        minYValue = _savingHistorySpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
        maxYValue = _savingHistorySpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    }

    double yRange = maxYValue - minYValue;
    if (yRange == 0) {
        minYValue -= 50; 
        maxYValue += 50; 
    } else {
        minYValue -= yRange * 0.1;
        maxYValue += yRange * 0.1;
    }
    if (minYValue == maxYValue) {
        minYValue = minYValue -1; maxYValue = maxYValue +1;
    }

    double currentMinX = _minTimestampX ?? DateTime.now().millisecondsSinceEpoch.toDouble();
    double currentMaxX = _maxTimestampX ?? (currentMinX + Duration(days: 1).inMilliseconds.toDouble());
    if (currentMinX >= currentMaxX) {
        currentMaxX = currentMinX + Duration(days: 1).inMilliseconds.toDouble();
    }
    
    return LineChartData(
      minX: currentMinX,
      maxX: currentMaxX,
      minY: minYValue,
      maxY: maxYValue,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
        getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: (currentMaxX - currentMinX) > 0 ? (currentMaxX - currentMinX) / 4 : Duration(days:1).inMilliseconds.toDouble(), // 0除算を避ける
            getTitlesWidget: (value, meta) {
              DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              return SideTitleWidget(
                // axisSide: meta.axisSide, // <-- この行を削除
                meta: meta, // metaを渡す (必須引数)
                space: 8.0,
                child: Text(DateFormat('MM/dd').format(date), style: TextStyle(color: appTheme.theme.foregroundColor, fontSize: 10)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                // axisSide: meta.axisSide, // <-- この行を削除
                meta: meta, // metaを渡す (必須引数)
                space: 8.0, // spaceの値を適切に設定（例として8.0）
                child: Text('RM${value.toInt()}', style: TextStyle(color: appTheme.theme.foregroundColor, fontSize: 10), textAlign: TextAlign.left),
              );
            },
            // interval: (maxYValue - minYValue) > 0 ? (maxYValue - minYValue) / 4 : 10, // Y軸のラベル間隔も調整可能, 0除算を避ける
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.4), width: 1)),
      lineBarsData: [
        LineChartBarData(
          spots: _savingHistorySpots,
          isCurved: true,
          color: appTheme.theme.shiokuriBlue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: appTheme.theme.shiokuriBlue.withOpacity(0.2)),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final flSpot = barSpot;
              DateTime date = DateTime.fromMillisecondsSinceEpoch(flSpot.x.toInt());
              return LineTooltipItem(
                '${DateFormat('MM/dd HH:mm').format(date)}\n',
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                    text: 'RM ${flSpot.y.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
                textAlign: TextAlign.center,
              );
            }).toList();
          },
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalExpenseAmount = _categoryExpenses.values.fold(0.0, (sum, item) => sum + item);

    return Scaffold(
      backgroundColor: appTheme.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: appTheme.theme.shiokuriBlue,
            borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(30),
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
        padding: const EdgeInsets.symmetric(horizontal:16.0),
        child: ListView( // 全体をスクロール可能にする
          children: <Widget>[
            // --- 月選択UI ---
            Row(
              children:[
                Icon(Icons.pie_chart, color: Colors.orange, size: 30),
                Text(' Total Expenses: RM ${totalExpenseAmount.toStringAsFixed(0)}',
                  style: appTheme.theme.title,
                ),
              ]
            ),
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
            const SizedBox(height: 20),

            // --- ローディング表示 ---
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 50.0),
                child: CircularProgressIndicator(),
              ))
            else ...[ // ローディングが終わったら以下のコンテンツを表示
              // --- 円グラフセクション ---
              if (_categoryExpenses.isNotEmpty) ...[
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
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: _generatePieChartSections(),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 250),
                    swapAnimationCurve: Curves.easeInOut,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children:[
                    Text(
                      "Category Breakdown",
                      textAlign: TextAlign.start,
                      style: appTheme.theme.subtitle,
                    ),
                  ]
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildLegend(),
                  ),
                ),
              ] else if (!_isLoading) ...[ // カテゴリ支出がない場合（ローディング後）
                  SizedBox(
                      height: 100,
                      child: Center(child: Text("No expense category data for this month.", style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]))),
                  )
              ],

              const SizedBox(height: 30), // セクション間の区切り

              // --- 貯金推移グラフセクション ---
              Row(
                children:[
                  Icon(Icons.trending_down, color: appTheme.theme.shiokuriBlue, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Saving Trend',
                    style: appTheme.theme.title.copyWith(color: appTheme.theme.foregroundColor),
                  ),
                ]
              ),
              const SizedBox(height: 16),
              _buildSavingHistoryChart(), // 新しい折れ線グラフウィジェット
            ],
            const SizedBox(height: 20), // 最下部の余白
          ],
        ),
      ),
    );
  }
}