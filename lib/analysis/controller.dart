import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:moneymanager/analysis/ViewModel.dart';
import 'package:moneymanager/model/expenseModel.dart'; // Ensure this path is correct
import 'package:moneymanager/uid/uid.dart'; // Ensure this path is correct

class AnalysisController {
  final AnalysisViewModel viewModel;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnalysisController({required this.viewModel});

  Future<void> fetchExpensesForCurrentMonth() async {
    viewModel.setLoading(true);

    try {
      final yearMonth = DateFormat('yyyy-MM').format(viewModel.currentMonth);
      final expensesCollection = _firestore
          .collection('expenses')
          .doc(userId.uid) // User specific document
          .collection(yearMonth);

      final expenseSnapshot = await expensesCollection
          .where('type', isEqualTo: 'expense')
          .get();

      if (expenseSnapshot.docs.isEmpty) {
        viewModel.setNoDataFound();
        return;
      }

      List<expenseModel> fetchedExpenses = expenseSnapshot.docs
          .map((doc) => expenseModel.fromFirestore(doc))
          .toList();

      _processAndSetFetchedData(fetchedExpenses);

    } catch (e) {
      // ignore: avoid_print
      print("Error fetching expenses in Controller: $e");
      // Optionally, update ViewModel with an error state to show in UI
      viewModel.setLoading(false); // Ensure loading is set to false on error
    }
  }

  void _processAndSetFetchedData(List<expenseModel> expenses) {
    double newTotalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

    Map<String, double> newCategoryMap = {};
    for (var expense in expenses) {
      final category = expense.category ?? "Others";
      newCategoryMap[category] = (newCategoryMap[category] ?? 0) + expense.amount;
    }

    Map<int, double> dailyTotalsMap = {};
    for (var expense in expenses) {
      // Assuming 'expense.date' is the day of the month (int).
      // If it's a DateTime object, use expense.date.day.
      // If it's a Timestamp, convert it: DateTime.fromMillisecondsSinceEpoch(expense.timestamp.millisecondsSinceEpoch).day
      int day = expense.date; 
      dailyTotalsMap[day] = (dailyTotalsMap[day] ?? 0) + expense.amount;
    }

    List<FlSpot> newSpots = [];
    int daysInMonth = viewModel.daysInCurrentMonth;
    for (int i = 1; i <= daysInMonth; i++) {
      newSpots.add(FlSpot(i.toDouble(), dailyTotalsMap[i] ?? 0.0));
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
      1, // Set to day 1 of the month to avoid issues with varying month lengths
    );
    viewModel.setMonth(newMonth);
    fetchExpensesForCurrentMonth(); // Fetch data for the new month
  }
}