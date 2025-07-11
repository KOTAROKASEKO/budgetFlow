import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:moneymanager/Transaction_Views/analysis/ViewModel.dart';
import 'package:moneymanager/Transaction_Views/analysis/controller.dart';
import 'package:moneymanager/Transaction_Views/setting.dart';
import 'package:moneymanager/apptheme.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:provider/provider.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnalysisController _analysisController;
  
  // MODIFIED: Add a flag to track the initial data load.
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // MODIFIED: This method is updated to safely fetch data after the first build.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = Provider.of<AnalysisViewModel>(context, listen: false);
    _analysisController = AnalysisController(viewModel: viewModel);

    // Only fetch data on the very first load.
    if (_isInitialLoad) {
      // This schedules the fetch to happen right after the build is complete, preventing the error.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analysisController.fetchExpensesForCurrentMonth();
      });
      // Set the flag to false so this doesn't run again.
      _isInitialLoad = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setting = Provider.of<Setting>(context);
    return Consumer<AnalysisViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
            backgroundColor: Colors.black,
            title: Text('Expense Analysis', style: AppTheme.darkTheme.textTheme.headlineMedium),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.shiokuriBlue),
                onPressed: () {
                  _analysisController.fetchExpensesForCurrentMonth();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMonthNavigator(viewModel, _analysisController),
                  const SizedBox(height: 20),
                  _buildTotalExpensesCard(viewModel, setting),
                  const SizedBox(height: 20),
                  _buildChartTabs(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPieChartSection(viewModel, setting),
                        _buildLineChartSection(viewModel, setting),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // ... no other changes are needed in the rest of the file ...

  Widget _buildMonthNavigator(AnalysisViewModel viewModel, AnalysisController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32, color: AppTheme.shiokuriBlue),
          onPressed: () => controller.changeMonth(-1),
        ),
        Text(
          viewModel.formattedCurrentMonthForDisplay,
          style: AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(fontSize: 18),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 32, color: AppTheme.shiokuriBlue),
          onPressed: () => controller.changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildTotalExpensesCard(AnalysisViewModel viewModel, Setting setting) {
    return Card(
      color: AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Expenses (${viewModel.formattedCurrentMonthForCard})',
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            viewModel.isLoading
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.shiokuriBlue)))
                : Text(
                    NumberFormat.currency(locale: 'en_US', symbol: setting.currency).format(viewModel.totalExpenses),
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

  Widget _buildPieChartSection(AnalysisViewModel viewModel, Setting setting) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.shiokuriBlue));
    }
    if (viewModel.categoryTotals.isEmpty && !viewModel.isLoading) {
      return Center(
        child: Text('No expense data for this month.', style: AppTheme.darkTheme.textTheme.bodyMedium),
      );
    }

    final List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    double totalForPercentage = viewModel.categoryTotals.values.fold(0.0, (sum, item) => sum + item);

    final sortedEntries = viewModel.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedEntries) {
      final percentage = totalForPercentage > 0 ? (entry.value / totalForPercentage * 100) : 0.0;
      sections.add(PieChartSectionData(
        color: AppTheme.chartColors[colorIndex % AppTheme.chartColors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50.0,
        titleStyle: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryText.withOpacity(0.9),
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ));
      colorIndex++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    // Optional: Handle touch events
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildPieChartLegend(viewModel, setting),
        ],
      ),
    );
  }

  Widget _buildPieChartLegend(AnalysisViewModel viewModel, Setting setting) {
    if (viewModel.categoryTotals.isEmpty) return const SizedBox.shrink();
    int colorIndex = 0;

    List<MapEntry<String, double>> sortedCategories = viewModel.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedCategories.map((entry) {
        final color = AppTheme.chartColors[colorIndex % AppTheme.chartColors.length];
        colorIndex++;
        final percentage = viewModel.totalExpenses > 0 ? (entry.value / viewModel.totalExpenses * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(width: 16, height: 16, color: color),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                height: 24,
                child: getIconForCategory(entry.key),
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
                 NumberFormat.currency(locale: 'en_US', symbol: setting.currency, decimalDigits: 2).format(entry.value),
                style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineChartSection(AnalysisViewModel viewModel, Setting setting) {
     if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.shiokuriBlue));
    }
    if (viewModel.dailyExpenseSpots.every((spot) => spot.y == 0) && !viewModel.isLoading) {
       return Center(
        child: Text('No daily spending data for this month.', style: AppTheme.darkTheme.textTheme.bodyMedium),
      );
    }

    double maxYValue = viewModel.dailyExpenseSpots.map((spot) => spot.y).fold(0.0, (prev, curr) => curr > prev ? curr : prev);
    if (maxYValue == 0) maxYValue = 100;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, right: 16, bottom: 12),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: maxYValue / 5, 
            verticalInterval: 5, 
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
                interval: 5, 
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day % 5 == 0 || day == 1 || day == viewModel.daysInCurrentMonth) {
                     return SideTitleWidget(
                      meta: meta,
                      space: 8.0,
                      child: Text(day.toString(), style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(fontSize: 10)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40, 
                interval: maxYValue / 5 > 0 ? (maxYValue / 5).ceilToDouble() : 20, 
                getTitlesWidget: (value, meta) {
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
          maxX: viewModel.daysInCurrentMonth.toDouble(),
          minY: 0,
          maxY: maxYValue * 1.1, 
          lineBarsData: [
            LineChartBarData(
              spots: viewModel.dailyExpenseSpots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [AppTheme.shiokuriBlue.withOpacity(0.8), AppTheme.shiokuriBlue.withOpacity(0.3)],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true, 
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
          lineTouchData: LineTouchData( 
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    'Day ${flSpot.x.toInt()}: ${setting.currency}${flSpot.y.toStringAsFixed(2)}\n',
                    AppTheme.darkTheme.textTheme.bodyMedium!.copyWith(color: AppTheme.primaryText, fontSize: 12),
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
  CategoryIcon({ required this.itemName, required this.itemIcon });
}

List<CategoryIcon> getMasterExpenseCategoriesWithIcons() {
  return [
    CategoryIcon(itemName: "Food",itemIcon: const Icon(Icons.food_bank, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Restaurant", itemIcon: const Icon(Icons.fastfood_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Transport", itemIcon: const Icon(Icons.directions_car_filled_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Shopping",itemIcon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Bills", itemIcon: const Icon(Icons.receipt_long_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Entertainment", itemIcon: const Icon(Icons.movie_filter_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Health", itemIcon: const Icon(Icons.healing_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Education", itemIcon: const Icon(Icons.school_outlined, color: AppTheme.shiokuriBlue)),
    CategoryIcon(itemName: "Others", itemIcon: const Icon(Icons.category_outlined, color: AppTheme.shiokuriBlue)),
  ];
}

Icon getIconForCategory(String categoryName) {
  final categories = getMasterExpenseCategoriesWithIcons();
  final category = categories.firstWhere(
    (c) => c.itemName.toLowerCase() == categoryName.toLowerCase(),
    orElse: () => CategoryIcon(itemName: "Others", itemIcon: const Icon(Icons.category_outlined, color: AppTheme.secondaryText)),
  );
  return category.itemIcon;
}