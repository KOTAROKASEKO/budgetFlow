import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart'; // Added Hive
import 'package:intl/intl.dart';
import 'package:moneymanager/Transaction_Views/analysis/ViewModel.dart';
import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart';
import 'package:moneymanager/uid/uid.dart'; // Assuming userId.uid is accessible

class AnalysisController {
  final AnalysisViewModel viewModel;
  // Removed FirebaseFirestore instance: final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnalysisController({required this.viewModel});

  Future<void> fetchExpensesForCurrentMonth() async {
    viewModel.setLoading(true);

    try {
      final yearMonth = DateFormat('yyyy-MM').format(viewModel.currentMonth);
      final cacheKey = '${userId.uid}_$yearMonth'; // Construct the Hive cache key

      // Ensure the box is open. It should be opened by dashBoardDBManager.init()
      // but accessing it ensures it's ready.
      final Box<List<dynamic>> expenseBox = Hive.box<List<dynamic>>('monthlyExpensesCache');
      
      List<dynamic>? cachedData = expenseBox.get(cacheKey);

      if (cachedData == null || cachedData.isEmpty) {
        viewModel.setNoDataFound();
        return;
      }

      // Cast to List<expenseModel> and filter for expenses only
      List<expenseModel> monthTransactions = cachedData.cast<expenseModel>().toList();
      List<expenseModel> fetchedExpenses = monthTransactions
          .where((transaction) => transaction.type == 'expense')
          .toList();

      if (fetchedExpenses.isEmpty) {
        viewModel.setNoDataFound();
        return;
      }
      
      // The amount in expenseModel for 'expense' type is already negative.
      // The original Firestore logic in AnalysisController expected positive amounts and summed them.
      // Dashboard's _calculateFinancialSummary uses item.amount directly for expense types (which are negative)
      // and then subtracts it from actualTotalSpending, effectively making it positive.
      // For analysis, we usually want to work with positive values for expenses when summing or charting.
      // Let's adjust the amounts to be positive for consistent processing in _processAndSetFetchedData.
      List<expenseModel> positiveAmountExpenses = fetchedExpenses.map((e) {
        return expenseModel(
            amount: e.amount.abs(), // Use absolute value for expenses
            date: e.date,
            id: e.id,
            description: e.description,
            category: e.category,
            type: e.type,
            timestamp: e.timestamp);
      }).toList();


      _processAndSetFetchedData(positiveAmountExpenses);

    } catch (e) {
      // ignore: avoid_print
      print("Error fetching expenses from Hive in Controller: $e");
      // Optionally, update ViewModel with an error state to show in UI
      viewModel.updateData(totalExpenses: 0, categoryTotals: {}, dailyExpenseSpots: [], isLoading: false);
      // viewModel.setLoading(false); // Ensure loading is set to false on error
    }
  }

  void _processAndSetFetchedData(List<expenseModel> expenses) {
    // Expenses now have positive amounts
    double newTotalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

    Map<String, double> newCategoryMap = {};
    for (var expense in expenses) {
      final category = expense.category ?? "Others";
      // Amounts are now positive
      newCategoryMap[category] = (newCategoryMap[category] ?? 0) + expense.amount;
    }

    Map<int, double> dailyTotalsMap = {};
    for (var expense in expenses) {
      int day = expense.date; 
      // Amounts are now positive
      dailyTotalsMap[day] = (dailyTotalsMap[day] ?? 0) + expense.amount;
    }

    List<FlSpot> newSpots = [];
    int daysInMonth = viewModel.daysInCurrentMonth;
    for (int i = 1; i <= daysInMonth; i++) {
      // Use positive daily totals for FlSpot
      newSpots.add(FlSpot(i.toDouble(), dailyTotalsMap[i]?.abs() ?? 0.0));
    }
    
    viewModel.updateData(
      totalExpenses: newTotalExpenses,
      categoryTotals: newCategoryMap,
      dailyExpenseSpots: newSpots,
    );
  }

  void changeMonth(int monthDelta) {
    DateTime newMonth = DateTime(
      viewModel.currentMonth.year,
      viewModel.currentMonth.month + monthDelta,
      1, 
    );
    viewModel.setMonth(newMonth);
    fetchExpensesForCurrentMonth(); 
  }
}