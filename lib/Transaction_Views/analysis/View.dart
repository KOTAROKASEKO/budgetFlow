import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:moneymanager/Transaction_Views/analysis/ViewModel.dart';
import 'package:moneymanager/Transaction_Views/analysis/controller.dart';
import 'package:moneymanager/apptheme.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:provider/provider.dart';
// ViewModel and Controller Imports


// CategoryIcon and helper functions (getMasterExpenseCategoriesWithIcons, getIconForCategory)
// should ideally be in a separate utility file (e.g., 'category_utils.dart') and imported.
// For brevity, their definitions are assumed to be the same as in your original file and accessible.
// Example: import 'utils/category_utils.dart';


class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnalysisController _analysisController;
  // ViewModel will be accessed via Provider

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // ViewModel is accessed via Provider, so no direct initialization here.
    // Controller will be initialized in didChangeDependencies or passed if needed.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Obtain the ViewModel from Provider. listen: false is important for one-time setup.
    final viewModel = Provider.of<AnalysisViewModel>(context, listen: false);
    // Initialize the Controller with the ViewModel
    _analysisController = AnalysisController(viewModel: viewModel);
    
    // Initial data fetch only if it hasn't been fetched yet (e.g., on first load)
    // ViewModel's isLoading can be used as a proxy for this.
    if (viewModel.isLoading && viewModel.totalExpenses == 0.0) { // Or a more specific "initialLoad" flag
        _analysisController.fetchExpensesForCurrentMonth();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to ViewModel changes and rebuild relevant parts
    return Consumer<AnalysisViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor, // Assuming 'theme' is accessible
          appBar: AppBar(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
            backgroundColor: Colors.black,
            title: Text('Expense Analysis', style: AppTheme.darkTheme.textTheme.headlineMedium),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.shiokuriBlue),
                onPressed: () {
                  // Trigger a refresh of the data
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
                  _buildTotalExpensesCard(viewModel),
                  const SizedBox(height: 20),
                  _buildChartTabs(), // Uses the local _tabController
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPieChartSection(viewModel),
                        _buildLineChartSection(viewModel),
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

  Widget _buildTotalExpensesCard(AnalysisViewModel viewModel) {
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
                    viewModel.formattedTotalExpenses,
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
      controller: _tabController, // Managed by _AnalysisScreenState
      tabs: const [
        Tab(text: 'BY CATEGORY'),
        Tab(text: 'DAILY TREND'),
      ],
    );
  }

  Widget _buildPieChartSection(AnalysisViewModel viewModel) {
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
        radius: 50.0, // Original radius
        titleStyle: TextStyle(
          fontSize: 12.0, // Original fontSize
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
                    // Optional: Handle touch events, possibly by calling controller/viewModel
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
          _buildPieChartLegend(viewModel),
        ],
      ),
    );
  }

  Widget _buildPieChartLegend(AnalysisViewModel viewModel) {
    // ... (Keep your existing _buildPieChartLegend implementation, ensuring it uses viewModel)
    // Example change: Replace _categoryTotals with viewModel.categoryTotals
    // Replace _totalExpenses with viewModel.totalExpenses
    // Replace getIconForCategory with the imported version if moved
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
                child: getIconForCategory(entry.key), // Assumes getIconForCategory is accessible
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

  Widget _buildLineChartSection(AnalysisViewModel viewModel) {
    // ... (Keep your existing _buildLineChartSection implementation, ensuring it uses viewModel)
    // Example change: Replace _dailyExpenseSpots with viewModel.dailyExpenseSpots
    // Replace _currentMonth with viewModel.currentMonth
    // Replace _isLoading with viewModel.isLoading
     if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.shiokuriBlue));
    }
    if (viewModel.dailyExpenseSpots.every((spot) => spot.y == 0) && !viewModel.isLoading) {
       return Center(
        child: Text('No daily spending data for this month.', style: AppTheme.darkTheme.textTheme.bodyMedium),
      );
    }

    double maxYValue = viewModel.dailyExpenseSpots.map((spot) => spot.y).fold(0.0, (prev, curr) => curr > prev ? curr : prev);
    if (maxYValue == 0) maxYValue = 100; // Default max Y if all values are 0

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
                    'Day ${flSpot.x.toInt()}: \$${flSpot.y.toStringAsFixed(2)}\n',
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

// Reminder: Move these helper classes/functions to a separate utility file.
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