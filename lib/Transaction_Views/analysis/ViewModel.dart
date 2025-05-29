import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalysisViewModel extends ChangeNotifier {
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;
  double _totalExpenses = 0.0;
  Map<String, double> _categoryTotals = {};
  List<FlSpot> _dailyExpenseSpots = [];

  // Getters for the UI to consume
  DateTime get currentMonth => _currentMonth;
  bool get isLoading => _isLoading;
  double get totalExpenses => _totalExpenses;
  Map<String, double> get categoryTotals => _categoryTotals;
  List<FlSpot> get dailyExpenseSpots => _dailyExpenseSpots;

  // Formatted getters for convenience
  String get formattedCurrentMonthForDisplay => DateFormat('MMMM yyyy').format(_currentMonth);
  String get formattedCurrentMonthForCard => DateFormat('MMMM').format(_currentMonth);
  String get formattedTotalExpenses => NumberFormat.currency(locale: 'en_US', symbol: '\$').format(_totalExpenses);
  int get daysInCurrentMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;


  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setMonth(DateTime month) {
    _currentMonth = month;
    // Reset data when month changes before fetching new data
    _totalExpenses = 0.0;
    _categoryTotals = {};
    _dailyExpenseSpots = [];
    // No need to call notifyListeners() here if fetchExpensesForCurrentMonth will do it
  }

  void updateData({
    required double totalExpenses,
    required Map<String, double> categoryTotals,
    required List<FlSpot> dailyExpenseSpots,
    bool isLoading = false, // Default to false once data is updated
  }) {
    _totalExpenses = totalExpenses;
    _categoryTotals = categoryTotals;
    _dailyExpenseSpots = dailyExpenseSpots;
    _isLoading = isLoading;
    notifyListeners();
  }
  
  void setNoDataFound() {
    _totalExpenses = 0.0;
    _categoryTotals = {};
    _dailyExpenseSpots = [];
    _isLoading = false;
    notifyListeners();
  }
}