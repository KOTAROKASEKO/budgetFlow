import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:moneymanager/apptheme.dart';
import 'package:moneymanager/model/expenseModel.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart'; // Assuming you use Firebase Auth

// Your expenseModel from the previous prompt

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with TickerProviderStateMixin {
  late DateTime _currentMonth;
  bool _isLoading = true;
  double _totalExpenses = 0.0;
  Map<String, double> _categoryTotals = {}; // For pie chart data
  List<FlSpot> _dailyExpenseSpots = []; // For line chart data

  late TabController _tabController;



  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _fetchExpensesForMonth();
  }

  Future<void> _fetchExpensesForMonth() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _totalExpenses = 0.0;
      _categoryTotals = {};
      _dailyExpenseSpots = [];
    });

    try {
      final yearMonth = DateFormat('yyyy-MM').format(_currentMonth);
      final expensesCollection = FirebaseFirestore.instance
          .collection('expenses')
          .doc(userId.uid) // User specific document
          .collection(yearMonth);

      final expenseSnapshot = await expensesCollection
          .where('type', isEqualTo: 'expense')
          .get();

      // final incomeSnapshot = await expensesCollection
      //     .where('type', isEqualTo: 'income')
      //     .get(); 

      if (expenseSnapshot.docs.isEmpty) {
         if (!mounted) return;
        setState(() => _isLoading = false); // No data, stop loading
        return;
      }

      List<expenseModel> fetchedExpenses = expenseSnapshot.docs
          .map((doc) => expenseModel.fromFirestore(doc))
          .toList();

      _processFetchedData(fetchedExpenses);

    } catch (e) {
      // ignore: avoid_print
      print("Error fetching expenses: $e");
      // You might want to show a user-friendly error message here
    } finally {
       if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _processFetchedData(List<expenseModel> expenses) {
    _totalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

    // Process for Pie Chart
    Map<String, double> categoryMap = {};
    for (var expense in expenses) {
      final category = expense.category ?? "Others";
      categoryMap[category] = (categoryMap[category] ?? 0) + expense.amount;
    }
    _categoryTotals = categoryMap;

    // Process for Line Chart
    Map<int, double> dailyTotalsMap = {};
    for (var expense in expenses) {
      // Ensure 'date' from model is day of month, or derive from timestamp
      int day = expense.date; // Assuming 'date' is correctly the day of month
      // Or, if 'date' isn't reliable for day:
      // int day = DateTime.fromMillisecondsSinceEpoch(expense.timestamp.millisecondsSinceEpoch).day;
      dailyTotalsMap[day] = (dailyTotalsMap[day] ?? 0) + expense.amount;
    }

    List<FlSpot> spots = [];
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      spots.add(FlSpot(i.toDouble(), dailyTotalsMap[i] ?? 0.0));
    }
    _dailyExpenseSpots = spots;
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + monthDelta,
        _currentMonth.day, // Keep the day, though month logic will handle it
      );
    });
    _fetchExpensesForMonth();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        
        title: Text('Expense Analysis', style: AppTheme.darkTheme.textTheme.headlineMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMonthNavigator(),
              const SizedBox(height: 20),
              _buildTotalExpensesCard(),
              const SizedBox(height: 20),
              _buildChartTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPieChartSection(),
                    _buildLineChartSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32, color: AppTheme.shiokuriBlue),
          onPressed: () => _changeMonth(-1),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_currentMonth),
          style: AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(fontSize: 18),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 32, color: AppTheme.shiokuriBlue),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildTotalExpensesCard() {
    return Card(
      color: AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Expenses (${DateFormat('MMMM').format(_currentMonth)})',
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.shiokuriBlue)))
                : Text(
                    NumberFormat.currency(locale: 'en_US', symbol: '\$').format(_totalExpenses), // Adjust locale & symbol
                    style: AppTheme.darkTheme.textTheme.displayLarge?.copyWith(color: AppTheme.primaryText),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTabs() {
    return TabBar(
      unselectedLabelColor: AppTheme.primaryText,
      controller: _tabController,
      tabs: const [
        Tab(text: 'BY CATEGORY'),
        Tab(text: 'DAILY TREND'),
      ],
    );
  }

  Widget _buildPieChartSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.shiokuriBlue));
    }
    if (_categoryTotals.isEmpty && !_isLoading) {
      return Center(
        child: Text('No expense data for this month.', style: AppTheme.darkTheme.textTheme.bodyMedium),
      );
    }

    final List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    double totalForPercentage = _categoryTotals.values.fold(0.0, (sum, item) => sum + item);

    // Sort categories by value descending
    final sortedEntries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedEntries) {
      final fontSize = 12.0;
      final radius = 50.0;
      final percentage = totalForPercentage > 0 ? (entry.value / totalForPercentage * 100) : 0.0;

      sections.add(PieChartSectionData(
        color: AppTheme.chartColors[colorIndex % AppTheme.chartColors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%', // Show percentage on slice
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryText.withOpacity(0.9),
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
        // badgeWidget: Text(entry.key, style: TextStyle(fontSize: 10, color: AppTheme.primaryText)), // Optional: category name as badge
        // badgePositionPercentageOffset: .98,
      ));
      colorIndex++;
    }

    return SingleChildScrollView( // Make the section scrollable if content overflows
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: 200, // Adjust height as needed
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    // setState(() { // For interactivity, update selected slice
                    //   if (!event.isInterestedForInteractions ||
                    //       pieTouchResponse == null ||
                    //       pieTouchResponse.touchedSection == null) {
                    //     touchedIndex = -1;
                    //     return;
                    //   }
                    //   touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    // });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2, // Space between slices
                centerSpaceRadius: 50, // For Donut chart style
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildPieChartLegend(),
        ],
      ),
    );
  }

  Widget _buildPieChartLegend() {
    if (_categoryTotals.isEmpty) return const SizedBox.shrink();
    int colorIndex = 0;

    // Sort categories for the legend, matching pie chart if possible
     List<MapEntry<String, double>> sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedCategories.map((entry) {
        final color = AppTheme.chartColors[colorIndex % AppTheme.chartColors.length];
        colorIndex++;
        final percentage = _totalExpenses > 0 ? (entry.value / _totalExpenses * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(width: 16, height: 16, color: color),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                height: 24,
                child: getIconForCategory(entry.key), // Using helper to get icon
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                 NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(entry.value),
                style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }


  Widget _buildLineChartSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.shiokuriBlue));
    }
    if (_dailyExpenseSpots.every((spot) => spot.y == 0) && !_isLoading) {
       return Center(
        child: Text('No daily spending data for this month.', style: AppTheme.darkTheme.textTheme.bodyMedium),
      );
    }

    double maxYValue = _dailyExpenseSpots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    if (maxYValue == 0) maxYValue = 100; // Default max Y if all values are 0 to show the grid

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, right: 16, bottom: 12),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: maxYValue / 5, // Adjust interval dynamically
            verticalInterval: 5, // Show a line every 5 days
            getDrawingHorizontalLine: (value) {
              return FlLine(color: AppTheme.secondaryText.withOpacity(0.2), strokeWidth: 0.8);
            },
            getDrawingVerticalLine: (value) {
              return FlLine(color: AppTheme.secondaryText.withOpacity(0.2), strokeWidth: 0.8);
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 5, // Show label every 5 days
                getTitlesWidget: (value, meta) {
                  if (value.toInt() % 5 == 0 || value.toInt() == 1 || value.toInt() == DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day) {
                     return SideTitleWidget(
                      meta: meta,
                      space: 8.0,
                      child: Text(value.toInt().toString(), style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(fontSize: 10)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40, // Adjust based on label size
                interval: maxYValue / 5 > 0 ? (maxYValue / 5).ceilToDouble() : 20, // Dynamic interval
                getTitlesWidget: (value, meta) {
                  // Basic formatting, can be improved (e.g., K for thousands)
                  return Text(NumberFormat.compact().format(value), style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.secondaryText.withOpacity(0.3), width: 1),
          ),
          minX: 1,
          maxX: DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day.toDouble(), // Days in month
          minY: 0,
          maxY: maxYValue * 1.1, // Add some padding to max Y
          lineBarsData: [
            LineChartBarData(
              spots: _dailyExpenseSpots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [AppTheme.shiokuriBlue.withOpacity(0.8), AppTheme.shiokuriBlue.withOpacity(0.3)],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true, // Show dots on points
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(radius: 3, color: AppTheme.primaryText, strokeWidth: 1, strokeColor: AppTheme.shiokuriBlue),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppTheme.shiokuriBlue.withOpacity(0.3), AppTheme.shiokuriBlue.withOpacity(0.05)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData( // Tooltip customization
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    'Day ${flSpot.x.toInt()}: \$${flSpot.y.toStringAsFixed(2)}\n',
                    AppTheme.darkTheme.textTheme.bodyMedium!.copyWith(color: AppTheme.primaryText, fontSize: 12),
                    children: [
                      // TextSpan(text: 'More details here if needed'),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}


class CategoryIcon {
  final String itemName;
  final Icon itemIcon;
  // Add a color field if you want each category to have a pre-defined unique color
  // final Color color;

  CategoryIcon({
    required this.itemName,
    required this.itemIcon,
    // this.color = AppTheme.shiokuriBlue, // Default color
  });
}

// Helper function to get master list of categories and their icons
// This helps in matching icons to categories from Firestore
List<CategoryIcon> getMasterExpenseCategoriesWithIcons() {
  return [
    CategoryIcon(
        itemName: "Food",
        itemIcon: const Icon(Icons.food_bank, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Restaurant", // Ensure Firestore 'category' matches "Restaurant"
        itemIcon: const Icon(Icons.fastfood_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Transport",
        itemIcon: const Icon(Icons.directions_car_filled_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Shopping",
        itemIcon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Bills",
        itemIcon: const Icon(Icons.receipt_long_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Entertainment",
        itemIcon: const Icon(Icons.movie_filter_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Health",
        itemIcon: const Icon(Icons.healing_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Education",
        itemIcon: const Icon(Icons.school_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(
        itemName: "Others",
        itemIcon: const Icon(Icons.category_outlined, color: AppTheme.shiokuriBlue)),
    // Add other categories as needed
  ];
}

// Function to find an icon for a given category name
Icon getIconForCategory(String categoryName) {
  final categories = getMasterExpenseCategoriesWithIcons();
  final category = categories.firstWhere(
    (c) => c.itemName.toLowerCase() == categoryName.toLowerCase(),
    orElse: () => CategoryIcon( // Default icon if not found
        itemName: "Others",
        itemIcon: const Icon(Icons.category_outlined, color: AppTheme.secondaryText)),
  );
  return category.itemIcon;
}


