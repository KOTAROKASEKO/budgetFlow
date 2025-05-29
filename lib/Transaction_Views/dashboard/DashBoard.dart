import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:moneymanager/feedback/feedback.dart';
import 'package:moneymanager/main.dart'; // Or your auth screen like UserAuthScreen
import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart'; // Ensure this path is correct and model is Hive-adapted
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart'; // Ensure userId.uid is available
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart'; // Import Hive

// Define TransactionType if it's not in ExpenseCategory.dart or elsewhere
enum TransactionType { expense, income }

class CategoryIcon {
  final String itemName;
  final Icon itemIcon;

  CategoryIcon({required this.itemName, required this.itemIcon});
}

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // Hive Box Names
  static const String _expenseCacheBoxName = 'monthlyExpensesCache';
  static const String _userSettingsBoxName = 'userSettings';

  String _category = "Food";
  int _budget = 0;
  int _avg = 0;
  int _total = 0;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int _pace = 0;

  List<expenseModel> _expenseModels = [];

  String _formattedDate = '';
  String _editedId = '';
  String _editingDateNum = ''; // For editing, stores the day of the month as string

  bool _isLoading = true;
  bool _doesExist = true;

  TransactionType _selectedType = TransactionType.expense;

  late TextEditingController _budgetInputController;
  late TextEditingController _expenseAmountController;
  late TextEditingController _expenseDescriptionController;
  late DraggableScrollableController _draggableController;

  bool _isOnline = true; // Consider using a connectivity plugin for real-time status
  late List<CategoryIcon> _categoryIcons;

  double _income = 0;

  Box<List<dynamic>> get _expenseBox => Hive.box<List<dynamic>>(_expenseCacheBoxName);
  Box get _settingsBox => Hive.box(_userSettingsBoxName);

  @override
  void initState() {
    super.initState();
    _budgetInputController = TextEditingController();
    _expenseDescriptionController = TextEditingController();
    _expenseAmountController = TextEditingController();
    _categoryIcons = _getExpenseCategoriesWithIcons(); // Initialize based on default type
    _draggableController = DraggableScrollableController();
    
    _initializeDateAndFetchData(); // Fetches data for current month
    _loadBudgetFromCacheOrFirestore(); // Loads budget
  }

  @override
  void dispose() {
    _draggableController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    _budgetInputController.dispose();
    super.dispose();
  }

  List<CategoryIcon> _getExpenseCategoriesWithIcons() {
    return [
      CategoryIcon(itemName: "Food", itemIcon: Icon(Icons.food_bank, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "restaurant", itemIcon: Icon(Icons.fastfood_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Transport", itemIcon: Icon(Icons.directions_car_filled_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Shopping", itemIcon: Icon(Icons.shopping_bag_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Bills", itemIcon: Icon(Icons.receipt_long_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Entertainment", itemIcon: Icon(Icons.movie_filter_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Health", itemIcon: Icon(Icons.healing_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Education", itemIcon: Icon(Icons.school_outlined, color: theme.shiokuriBlue)),
      CategoryIcon(itemName: "Others", itemIcon: Icon(Icons.category_outlined, color: theme.shiokuriBlue)),
    ];
  }

  List<CategoryIcon> _getIncomeCategoriesWithIcons() {
    return [
      CategoryIcon(itemName: "Salary", itemIcon: Icon(Icons.payments_outlined, color: Colors.green[700])),
      CategoryIcon(itemName: "Gifts", itemIcon: Icon(Icons.card_giftcard_outlined, color: Colors.orange[700])),
      CategoryIcon(itemName: "Sales", itemIcon: Icon(Icons.trending_up_outlined, color: Colors.blue[700])),
      CategoryIcon(itemName: "Investment", itemIcon: Icon(Icons.account_balance_outlined, color: Colors.purple[700])),
      CategoryIcon(itemName: "Rental", itemIcon: Icon(Icons.real_estate_agent_outlined, color: Colors.brown[700])),
      CategoryIcon(itemName: "Freelance", itemIcon: Icon(Icons.work_outline, color: Colors.teal[700])),
      CategoryIcon(itemName: "Refunds", itemIcon: Icon(Icons.replay_outlined, color: Colors.cyan[700])),
      CategoryIcon(itemName: "Others", itemIcon: Icon(Icons.attach_money_outlined, color: Colors.grey[700])),
    ];
  }

  void _initializeDateAndFetchData() {
    DateTime now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _formattedDate = "$_year-${_month.toString().padLeft(2, '0')}";
    fetchData(_formattedDate);
  }

  Future<void> _loadBudgetFromCacheOrFirestore() async {
    final budgetCacheKey = '${userId.uid}_budget';
    final cachedBudget = _settingsBox.get(budgetCacheKey);

    if (cachedBudget != null && cachedBudget is int) {
      if (mounted) {
        setState(() {
          _budget = cachedBudget;
        });
      }
    } else {
      try {
        DocumentSnapshot budgetDoc = await FirebaseFirestore.instance
            .collection("budget")
            .doc(userId.uid)
            .get();
        if (mounted) {
          if (budgetDoc.exists) {
            _budget = (budgetDoc.data() as Map<String, dynamic>)['budget'] ?? 0;
            await _settingsBox.put(budgetCacheKey, _budget);
          } else {
            _budget = 0; // Default if not set in Firestore
            await _settingsBox.put(budgetCacheKey, _budget); // Cache default
          }
          setState(() {}); // Update UI if budget changed
        }
      } catch (e) {
        print("Error fetching budget from Firestore: $e");
        if (mounted) {
          setState(() => _budget = 0); // Fallback on error
        }
      }
    }
    if (mounted) {
       _calculateFinancialSummary(); // Recalculate summary with the budget
    }
  }

  Future<void> _fetchFromFirestoreAndUpdateCache(String dateToFetch) async {
    if (!_isOnline && _expenseModels.isEmpty && !_isLoading) { // Added _isLoading check
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    var parts = dateToFetch.split('-');
    _year = int.parse(parts[0]);
    _month = int.parse(parts[1]);
    _formattedDate = dateToFetch;


    if (mounted) setState(() => _isLoading = true);

    try {
      QuerySnapshot expensesSnapshot = await FirebaseFirestore.instance
          .collection("expenses")
          .doc(userId.uid)
          .collection(dateToFetch)
          .orderBy("timestamp", descending: true)
          .get();

      if (mounted) {
        List<expenseModel> fetchedExpenses = [];
        for (var doc in expensesSnapshot.docs) {
          fetchedExpenses.add(expenseModel.fromFirestore(doc));
        }
        _expenseModels = fetchedExpenses;

        final cacheKey = '${userId.uid}_$dateToFetch';
        // Hive stores a list of HiveObjects. Ensure they are correctly adapted.
        await _expenseBox.put(cacheKey, _expenseModels.toList());

        _calculateFinancialSummary();
        setState(() {
          _isLoading = false;
          _doesExist = _expenseModels.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error fetching data from cloud: $e"),
              backgroundColor: Colors.redAccent),
        );
      }
      print("Error fetching data from cloud: $e");
    }
  }

  Future<void> fetchData(String dateToFetch) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _formattedDate = dateToFetch;
        var parts = dateToFetch.split('-');
        _year = int.parse(parts[0]);
        _month = int.parse(parts[1]);
      });
    }

    final cacheKey = '${userId.uid}_$dateToFetch';
    // Ensure the box is open and ready before trying to get data
    // This should be handled by main.dart initialization
    List<dynamic>? cachedDynamicData = _expenseBox.get(cacheKey);
    
    if (cachedDynamicData != null) {
        print("Loading expenses from cache for $dateToFetch");
        // Cast to List<expenseModel>
        _expenseModels = cachedDynamicData.cast<expenseModel>().toList();

        // Re-sort as Hive list might not preserve order exactly as Firestore query
        _expenseModels.sort((a, b) {
            if (a.timestamp == null && b.timestamp == null) return 0;
            if (a.timestamp == null) return 1;
            if (b.timestamp == null) return -1;
            return b.timestamp!.compareTo(a.timestamp!);
        });
        
        if (mounted) {
            _calculateFinancialSummary();
            setState(() {
            _isLoading = false;
            _doesExist = _expenseModels.isNotEmpty;
            });
        }
        return;
    }


    print("No cache found for $dateToFetch or cache empty, fetching from Firestore.");
    await _fetchFromFirestoreAndUpdateCache(dateToFetch);
  }

  void _calculateFinancialSummary() {
    if (!mounted) return;

    DateTime today = DateTime.now();
    double calculatedTotalIncome = 0;
    double actualTotalSpending = 0;

    if (_expenseModels.isEmpty) {
      setState(() {
        _total = 0;
        _avg = 0;
        _income = 0;
        _pace = 0; // Default pace if no expenses and no budget goal to track against this way

        // If you want pace to reflect potential savings against budget even with no expenses:
        int daysForIdealCalc;
        if (_year == today.year && _month == today.month) {
          daysForIdealCalc = today.day > 0 ? today.day : 1;
        } else {
          daysForIdealCalc = DateTime(_year, _month + 1, 0).day; // Days in the month
        }
        double idealSpendingSoFar = _budget * daysForIdealCalc.toDouble();
        _pace = idealSpendingSoFar.round(); // You're on track by the full budgeted amount
      });
      return;
    }

    // Sort by day of month ascending for some calculations if needed,
    // but for sums, original order (or timestamp order) is fine.
    // monthTransactionsForCalc.sort((a, b) => a.date.compareTo(b.date));

    for (var item in _expenseModels) {
      if (item.type == 'expense') {
        actualTotalSpending -= item.amount; // item.amount is negative for expenses
      } else if (item.type == 'income') {
        calculatedTotalIncome += item.amount;
      }
    }

    int daysForPacePeriod;
    expenseModel? firstExpenseDataThisMonth;
    // Find first expense day for current month pace calculation
    if (_year == today.year && _month == today.month) {
        List<expenseModel> currentMonthExpenses = _expenseModels
            .where((e) => e.type == 'expense')
            .toList()..sort((a,b) => a.date.compareTo(b.date)); // sort by day of month
        if(currentMonthExpenses.isNotEmpty){
            firstExpenseDataThisMonth = currentMonthExpenses.first;
        }

        if (firstExpenseDataThisMonth != null) {
            int firstExpenseDay = firstExpenseDataThisMonth.date;
            if (today.day >= firstExpenseDay) {
                daysForPacePeriod = today.day - firstExpenseDay + 1;
            } else { // First expense is in the future (data error?) or not yet occurred
                daysForPacePeriod = today.day > 0 ? today.day : 1;
            }
        } else { // No expenses yet this month
            daysForPacePeriod = today.day > 0 ? today.day : 1;
        }
    } else { // For past or future months
        List<expenseModel> relevantMonthExpenses = _expenseModels
            .where((e) => e.type == 'expense')
            .toList()..sort((a,b) => a.date.compareTo(b.date));
        if(relevantMonthExpenses.isNotEmpty){
            // For past month, pace period is up to the last expense day of that month
            daysForPacePeriod = relevantMonthExpenses.last.date;
        } else {
            // No expenses in that month, use total days of month for ideal calc if needed
            daysForPacePeriod = DateTime(_year, _month + 1, 0).day;
        }
    }
    daysForPacePeriod = daysForPacePeriod > 0 ? daysForPacePeriod : 1;

    _total = actualTotalSpending.round();
    _avg = (actualTotalSpending > 0 && daysForPacePeriod > 0) 
           ? (actualTotalSpending / daysForPacePeriod).round() 
           : 0;

    double idealSpendingToDate = _budget * daysForPacePeriod.toDouble();
    _pace = (idealSpendingToDate - actualTotalSpending).round();

    if (mounted) {
      setState(() {
        _income = calculatedTotalIncome;
      });
    }
  }

  Future<void> _refresh() async {
    await _fetchFromFirestoreAndUpdateCache(_formattedDate);
  }

  void _openBudgetDialog() {
    _budgetInputController.text = _budget.toString();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: const Text("Set Daily Budget", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: _budgetInputController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: "RM ",
              hintText: "e.g., 50",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.shiokuriBlue, width: 2),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          actions: [
            TextButton(
              child: Text("Cancel", style: TextStyle(color: Colors.grey[700], fontSize: 16)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.shiokuriBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              ),
              child: const Text("Save", style: TextStyle(fontSize: 16)),
              onPressed: () async {
                final int? newBudget = int.tryParse(_budgetInputController.text);
                if (newBudget != null && newBudget >= 0) {
                  try {
                    await FirebaseFirestore.instance
                        .collection("budget")
                        .doc(userId.uid)
                        .set({"budget": newBudget});
                    
                    await _settingsBox.put('${userId.uid}_budget', newBudget);

                    if (mounted) {
                      setState(() => _budget = newBudget);
                      _calculateFinancialSummary();
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Daily budget updated to RM $newBudget.'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to update budget: $e'),
                            backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a valid budget amount.'),
                          backgroundColor: Colors.orangeAccent),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddEditExpenseSheet({expenseModel? expenseToEdit}) {
    bool isEditing = expenseToEdit != null;

    setState(() {
      if (isEditing) {
        _selectedType = (expenseToEdit.type == "income") ? TransactionType.income : TransactionType.expense;
        _editedId = expenseToEdit.id;
        _expenseAmountController.text = expenseToEdit.amount.abs().toStringAsFixed(2); // Use absolute for editing
        _expenseDescriptionController.text = expenseToEdit.description ?? '';
        _category = expenseToEdit.category ?? (_selectedType == TransactionType.expense ? 'Others' : 'Salary');
        _editingDateNum = expenseToEdit.date.toString();
      } else {
        _selectedType = TransactionType.expense; // Default to expense when adding
        _editedId = '';
        _expenseAmountController.clear();
        _expenseDescriptionController.clear();
        _category = "Food"; // Default expense category
        _editingDateNum = DateTime.now().day.toString();
      }
       _categoryIcons = _selectedType == TransactionType.expense
            ? _getExpenseCategoriesWithIcons()
            : _getIncomeCategoriesWithIcons();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddEditExpenseSheetContent(isEditing: isEditing),
    ).then((_) {
        // Always re-initialize the draggable controller after closing the sheet
        _draggableController = DraggableScrollableController();
        // Reset category lists for next time
        _categoryIcons = _getExpenseCategoriesWithIcons(); 
    });
  }
  
  // --- Build Methods & UI Widgets ---
  // All the build methods (_buildBody, _buildOfflineMessage, _buildSummaryCard, etc.)
  // should largely remain the same as they operate on the state variables (_expenseModels, _budget, etc.)
  // which are now managed with caching.

  @override
  Widget build(BuildContext context) {
    //print("Dashboard build method called. isLoading: $_isLoading, doesExist: $_doesExist, models: ${_expenseModels.length}");
    return Scaffold(
      drawer: GestureDetector(
        onTap: () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
        child: Drawer(
          backgroundColor: const Color(0xFF1A1A1A),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  decoration: BoxDecoration(color: theme.shiokuriBlue.withOpacity(0.15)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.shiokuriBlue,
                        child: const Icon(Icons.account_balance_wallet_rounded, size: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text("Finance Planner", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text("Version 1.6.1", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8.0),
                    children: [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.exit_to_app_outlined,
                        text: 'Sign Out',
                        accentColor: theme.shiokuriBlue,
                        onTap: () async {
                          Navigator.pop(context);
                          await signOut(context);
                        },
                      ),
                      const Divider(color: Colors.white12, indent: 20, endIndent: 20, height: 1),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.feedback_outlined,
                        text: 'Send Feedback',
                        accentColor: theme.shiokuriBlue,
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))),
                            builder: (BuildContext modalContext) => FeedbackForm(),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.info_outline_rounded,
                        text: 'About Us',
                        accentColor: theme.shiokuriBlue,
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                              context: context,
                              builder: (context) => AboutDialog(
                                    applicationName: 'Finance Planner',
                                    applicationVersion: '1.6.1',
                                    applicationIcon: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: theme.shiokuriBlue,
                                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                                    ),
                                    applicationLegalese: '© ${DateTime.now().year} kotaro.sdn.bhd',
                                    children: <Widget>[
                                      const SizedBox(height: 15),
                                      const Text('This app helps you manage your finances efficiently.'),
                                    ],
                                  ));
                        },
                      ),
                      const Divider(color: Colors.white12, indent: 20, endIndent: 20, height: 1),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
                  child: Text(
                    "Your finances, simplified.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.shiokuriBlue,
        elevation: 1,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        title: Text("Finance Dashboard", style: theme.subtitle),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.shiokuriBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_outlined),
        label: const Text("New Transaction"), // Changed label for clarity
        onPressed: () => _showAddEditExpenseSheet(),
        elevation: 4.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isOnline && _expenseModels.isEmpty && !_isLoading) {
      return _buildOfflineMessage();
    }
    return Column(
      children: [
        _buildSummarySection(),
        _buildMonthNavigator(),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 5, bottom: 5), // Added bottom margin
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 0,
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  )
                ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: LiquidPullToRefresh(
                color: theme.shiokuriBlue.withAlpha(180),
                backgroundColor: Colors.white,
                springAnimationDurationInMilliseconds: 350,
                onRefresh: _refresh,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.shiokuriBlue)))
                    : _doesExist
                        ? _buildExpenseList()
                        : _buildNoRecordsMessage(isEmpty: true),
              ),
            ),
          ),
        ),
        const SizedBox(height: 60), // Space for FAB
      ],
    );
  }

  Widget _buildOfflineMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 90, color: Colors.grey[400]),
            const SizedBox(height: 25),
            Text('You Are Offline', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 12),
            Text('Please check your internet connection to sync and view the latest data.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 35),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.shiokuriBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onPressed: () {
                // Ideally, check connectivity status first
                // For now, just trigger a fetch which will use cache or cloud
                fetchData(_formattedDate);
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color iconColor, Color valueColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.0),
      child: Card(
        elevation: 2.5,
        shadowColor: Colors.grey.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 10),
              Text("RM $value", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaceCard() {
    bool isSaving = _pace >= 0;
    Color paceColor = isSaving ? Colors.green.shade600 : Colors.red.shade600;
    IconData paceIcon = isSaving ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    String paceTitle = isSaving ? "On Track (Saving)" : "Overspent";

    return _buildSummaryCard(paceTitle, _pace.abs().toString(), paceIcon, paceColor, paceColor);
  }

  Widget _buildSummarySection() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(10, 12.0, 10, 8.0), // Added horizontal padding
        child: SizedBox( // Used SizedBox instead of ConstrainedBox for ListView
            height: 110, // Fixed height for horizontal list
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSummaryCard("Daily Budget", _budget.toString(), Icons.account_balance_wallet_outlined, theme.shiokuriBlue, Colors.black87, onTap: _openBudgetDialog),
                _buildSummaryCard("Avg / Day", _avg.toString(), Icons.data_usage_rounded, Colors.orangeAccent.shade700, Colors.black87),
                _buildSummaryCard('Total Expense', _total.toString(), Icons.arrow_downward_rounded, Colors.red.shade400, Colors.black87),
                _buildSummaryCard('Total Income', _income.round().toString(), Icons.arrow_upward_rounded, Colors.green.shade500, Colors.black87),
                _buildPaceCard(),
              ].map((widget) => Padding(padding: const EdgeInsets.only(right:8.0), child: widget)).toList(), // Add spacing between cards
            )));
  }

  Widget _buildMonthNavigator() {
    String monthName = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.foregroundColor, size: 20),
            onPressed: () {
              DateTime newDate = DateTime(_year, _month -1);
              fetchData("${newDate.year}-${newDate.month.toString().padLeft(2, '0')}");
            },
          ),
          Text(monthName, style: theme.normal),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, color: theme.foregroundColor, size: 20),
            onPressed: () {
              DateTime newDate = DateTime(_year, _month + 1);
              fetchData("${newDate.year}-${newDate.month.toString().padLeft(2, '0')}");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenseModels.isEmpty) return _buildNoRecordsMessage(isEmpty: true);

    Map<int, List<expenseModel>> groupedExpenses = {};
    for (var expense in _expenseModels) {
      (groupedExpenses[expense.date] ??= []).add(expense);
    }
    // Sort days descending
    var sortedDays = groupedExpenses.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.separated(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 85),
      itemCount: sortedDays.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, dayIndex) {
        int day = sortedDays[dayIndex];
        List<expenseModel> dayExpenses = groupedExpenses[day]!;
        // Sort expenses within the day by timestamp descending (most recent first)
        dayExpenses.sort((a,b) {
            if(a.timestamp == null && b.timestamp == null) return 0;
            if(a.timestamp == null) return 1;
            if(b.timestamp == null) return -1;
            return b.timestamp!.compareTo(a.timestamp!);
        });


        String daySuffix = "th";
        if (day % 10 == 1 && day % 100 != 11) daySuffix = "st";
        else if (day % 10 == 2 && day % 100 != 12) daySuffix = "nd";
        else if (day % 10 == 3 && day % 100 != 13) daySuffix = "rd";

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18.0, top: 10.0, bottom: 6.0),
                child: Text(
                  "$day$daySuffix ${DateFormat('MMM').format(DateTime(_year, _month, day))}",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
                ),
              ),
              ...dayExpenses.map((expense) => _buildExpenseTile(expense)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseTile(expenseModel expense) {
    // Determine which category list to use based on expense type
    final currentCategorySet = (expense.type == "income") 
                                ? _getIncomeCategoriesWithIcons() 
                                : _getExpenseCategoriesWithIcons();

    final categoryIconData = currentCategorySet.firstWhere(
        (iconData) => iconData.itemName.toLowerCase() == (expense.category?.toLowerCase() ?? ''),
        orElse: () => CategoryIcon(
            itemName: "Others",
            itemIcon: Icon(Icons.label_outline_rounded, 
                         color: (expense.type == "income") ? Colors.green : theme.shiokuriBlue))
    );
    
    bool isIncome = expense.type == "income";
    // Amount is stored signed in expenseModel: negative for expense, positive for income
    String displayAmount = isIncome 
        ? "+ RM ${expense.amount.toStringAsFixed(2)}" 
        : "  RM ${expense.amount.abs().toStringAsFixed(2)}"; // Show positive for expense display

    Color amountColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;


    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryIconData.itemIcon.color?.withOpacity(0.12) ?? theme.shiokuriBlue.withOpacity(0.12),
          child: IconTheme(
              data: IconThemeData(color: categoryIconData.itemIcon.color ?? theme.shiokuriBlue, size: 22),
              child: categoryIconData.itemIcon),
        ),
        title: Text(
          expense.description != null && expense.description!.isNotEmpty ? expense.description! : (expense.category ?? (isIncome ? "Income" : "Expense")),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(displayAmount, style: TextStyle(color: amountColor, fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right_rounded, size: 22, color: Colors.grey[400]),
        onTap: () => _showExpenseOptionsSheet(expense),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
    );
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => UserAuthScreen()), // Replace with your actual Auth/Login Screen
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      print('Failed to sign out: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: ${e.message ?? "Unknown error"}'), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      print('An unexpected error occurred during sign out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred. Please try again.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showExpenseOptionsSheet(expenseModel expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isIncome = expense.type == "income";
        String title = isIncome ? "Income Details" : "Expense Details";
        String editTitle = isIncome ? "Edit Income" : "Edit Expense";
        String deleteTitle = isIncome ? "Delete Income" : "Delete Expense";

        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 45, height: 5, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  expense.description != null && expense.description!.isNotEmpty ? expense.description! : title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "RM ${expense.amount.abs().toStringAsFixed(2)}  •  Category: ${expense.category ?? 'N/A'}",
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: Colors.grey[200]),
              ListTile(
                leading: Icon(Icons.edit_note_rounded, color: theme.shiokuriBlue, size: 26),
                title: Text(editTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEditExpenseSheet(expenseToEdit: expense);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              ),
              ListTile(
                leading: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 26),
                title: Text(deleteTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  _confirmDeleteTransaction(expense); // Generic name now
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteTransaction(expenseModel transaction) { // Renamed from _confirmDeleteExpense
    bool isIncome = transaction.type == "income";
    String itemType = isIncome ? "income" : "expense";
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Confirm Deletion', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "${transaction.description != null && transaction.description!.isNotEmpty ? transaction.description : "this $itemType"}"? This action cannot be undone.'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  // Firestore delete
                  await FirebaseFirestore.instance
                      .collection("expenses") // Collection still named "expenses"
                      .doc(userId.uid)
                      .collection(_formattedDate) // Assumes deletion is for the currently viewed month
                      .doc(transaction.id)
                      .delete();

                  // Update Local Cache
                  final cacheCollectionKey = '${userId.uid}_$_formattedDate';
                  List<expenseModel> cachedMonthTransactions = 
                      (_expenseBox.get(cacheCollectionKey) ?? []).map((e) => e as expenseModel).toList();
                  
                  cachedMonthTransactions.removeWhere((e) => e.id == transaction.id);
                  await _expenseBox.put(cacheCollectionKey, cachedMonthTransactions);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${itemType[0].toUpperCase()}${itemType.substring(1)} deleted successfully.'), backgroundColor: Colors.green),
                    );
                    fetchData(_formattedDate); // Reload data
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete $itemType: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerItem({required BuildContext context, required IconData icon, required String text, required GestureTapCallback onTap, required Color accentColor}) {
    return ListTile(
      leading: Icon(icon, color: theme.foregroundColor, size: 24),
      title: Text(text, style: TextStyle(fontSize: 15.5, color: Colors.white.withOpacity(0.87), fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 12.0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: Colors.white.withOpacity(0.05),
      splashColor: accentColor.withOpacity(0.1),
    );
  }

  Widget _buildNoRecordsMessage({bool isEmpty = false}) {
    String message = isEmpty
        ? 'No transactions recorded for ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}.'
        : 'Pull down to refresh or try again later.';
    String subMessage = isEmpty
        ? "Tap '+' to add a new transaction and get started!"
        : 'Could not load records at this time.';

    return LayoutBuilder(
        builder: (context, constraints) {
      return SingleChildScrollView( // Essential for LiquidPullToRefresh to work with empty/small content
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEmpty ? Icons.inbox_outlined : Icons.cloud_off_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Text(subMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAddEditExpenseSheetContent({required bool isEditing}) {
    // This StatefulBuilder is crucial for the sheet to manage its own state for UI updates like error messages or selected category display within the sheet.
    // _selectedType and _category are now managed by the parent _DashboardState.
    // The sheetContent will read them from the parent.
    
    final themeData = Theme.of(context); // Using Theme.of(context) from the parent widget.
    final Color primarySheetColor = _selectedType == TransactionType.expense ? themeData.colorScheme.primary : Colors.green[700]!;
    
    // Use the _categoryIcons from the parent state, which is updated in _showAddEditExpenseSheet
    final List<CategoryIcon> currentCategories = _categoryIcons; 
    final String defaultCategoryForType = _selectedType == TransactionType.expense ? "Food" : "Salary";

    String localErrorText = ""; // Error text local to the sheet

    return StatefulBuilder( // This builder is for the content of the sheet
      builder: (BuildContext sheetContext, StateSetter setSheetState) {
        
        void selectCategoryAndUpdateState(String newCategory) {
          // Update parent state's _category
          if (mounted && _category != newCategory) { // Check mounted for parent state
            setState(() {
              _category = newCategory;
            });
            // No need to call setSheetState here unless the sheet itself needs an immediate re-render for this change
            // The parent's setState will trigger a rebuild of the sheet if necessary.
          }
        }

        void selectTypeAndUpdateState(int index) {
            TransactionType newType = index == 0 ? TransactionType.expense : TransactionType.income;
            if (mounted && _selectedType != newType) {
                setState(() { // This is _DashboardState.setState
                    _selectedType = newType;
                    _category = _selectedType == TransactionType.expense ? "Food" : "Salary"; // Reset category
                    _categoryIcons = _selectedType == TransactionType.expense // Update available categories
                                    ? _getExpenseCategoriesWithIcons()
                                    : _getIncomeCategoriesWithIcons();
                    localErrorText = ""; // Clear local error when type changes
                });
                // Important: To make the StatefulBuilder for the sheet update its own UI (like toggle buttons, colors based on newType)
                setSheetState(() {}); 
            }
        }


        return DraggableScrollableSheet(
          key: ValueKey(isEditing ? _editedId : _selectedType.toString() + _category), // More specific key
          controller: _draggableController,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (modalContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, spreadRadius: 1)],
              ),
              padding: EdgeInsets.only(left: 22, right: 22, top: 12, bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20),
              child: ListView(
                controller: scrollController,
                children: <Widget>[
                  Center(child: Container(width: 45, height: 5, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  Text(
                    isEditing
                        ? (_selectedType == TransactionType.expense ? 'Edit Expense' : 'Edit Income')
                        : (_selectedType == TransactionType.expense ? 'Add New Expense' : 'Add New Income'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primarySheetColor),
                  ),
                  const SizedBox(height: 15),

                  if (!isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: ToggleButtons(
                          isSelected: [_selectedType == TransactionType.expense, _selectedType == TransactionType.income],
                          onPressed: selectTypeAndUpdateState,
                          borderRadius: BorderRadius.circular(10),
                          selectedColor: Colors.white,
                          fillColor: primarySheetColor.withOpacity(0.9),
                          color: primarySheetColor,
                          constraints: BoxConstraints(minHeight: 40.0, minWidth: (MediaQuery.of(sheetContext).size.width - 80) / 2),
                          children: const <Widget>[
                            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Expense', style: TextStyle(fontWeight: FontWeight.w600))),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Income', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    ),
                  if (!isEditing) const SizedBox(height: 15),

                  TextField(
                    controller: _expenseAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (RM)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.monetization_on_outlined, color: primarySheetColor, size: 22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primarySheetColor, width: 2), borderRadius: BorderRadius.circular(14)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                    onTap: () => _draggableController.animateTo(0.95, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: _expenseDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.description_outlined, color: primarySheetColor, size: 22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primarySheetColor, width: 2), borderRadius: BorderRadius.circular(14)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                    onTap: () => _draggableController.animateTo(0.95, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  ),
                  const SizedBox(height: 22),

                  Text('Selected Category: $_category', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                  const SizedBox(height: 12),

                  Container(
                    height: 180, // Adjust height as needed
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                    child: GridView.builder(
                      physics: const ClampingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.9,
                      ),
                      itemCount: currentCategories.length, // Uses parent state's _categoryIcons
                      itemBuilder: (context, index) {
                        final item = currentCategories[index];
                        bool isSelected = _category == item.itemName; // Reads parent state's _category
                        Color itemColor = item.itemIcon.color ?? primarySheetColor;

                        return GestureDetector(
                          onTap: () => selectCategoryAndUpdateState(item.itemName),
                          child: Tooltip(
                            message: item.itemName,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? itemColor.withOpacity(0.15) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? itemColor : Colors.grey[300]!, width: isSelected ? 1.8 : 1.2),
                                    boxShadow: isSelected ? [BoxShadow(color: itemColor.withOpacity(0.2), blurRadius: 5, spreadRadius: 1)] : [],
                                  ),
                                  child: IconTheme(data: IconThemeData(color: isSelected ? itemColor : Colors.grey[700], size: 26), child: item.itemIcon),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.itemName,
                                  style: TextStyle(fontSize: 10.5, color: isSelected ? itemColor : Colors.grey[700], fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                                  overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (localErrorText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
                      child: Text(localErrorText, style: const TextStyle(color: Colors.redAccent, fontSize: 14.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 25),

                  ElevatedButton.icon(
                    icon: Icon(isEditing ? Icons.check_circle_outline_rounded : Icons.add_circle_outline_rounded, size: 22),
                    label: Text(
                        isEditing
                            ? (_selectedType == TransactionType.expense ? 'Update Expense' : 'Update Income')
                            : (_selectedType == TransactionType.expense ? 'Save Expense' : 'Save Income'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primarySheetColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    onPressed: () async {
                      final String amountStr = _expenseAmountController.text.trim();
                      final String descriptionStr = _expenseDescriptionController.text.trim();
                      final double? enteredAmount = double.tryParse(amountStr);

                      if (enteredAmount == null || enteredAmount <= 0) {
                        setSheetState(() => localErrorText = "Please enter a valid positive amount.");
                        return;
                      }
                      
                      // Validate category (ensure it's in the current list for the selected type)
                      bool categoryIsValid = currentCategories.any((cat) => cat.itemName == _category);
                      if (_category.isEmpty || !categoryIsValid) {
                          // If invalid, try to set a default or show error
                          // This check might be redundant if _category is always set from lists.
                          setSheetState(() => localErrorText = "Please select a valid category.");
                          // Fallback, though _category should always be valid if selected from grid
                          if(mounted) {
                            setState(() {
                               _category = defaultCategoryForType;
                            });
                          }
                          return;
                      }
                      setSheetState(() => localErrorText = "");

                      String docId = isEditing ? _editedId : const Uuid().v4();
                      
                      // Use _formattedDate from the parent _DashboardState for the month/year context
                      // This means transactions are added/edited for the currently viewed month.
                      String transactionMonthYearKey = _formattedDate; 
                      int transactionDay;

                      if (isEditing && _editingDateNum.isNotEmpty) {
                          transactionDay = int.tryParse(_editingDateNum) ?? DateTime.now().day;
                      } else {
                          // For new items, use the current day of the month shown on the dashboard
                          // Or allow user to pick a day within the current _formattedDate (not implemented here)
                          transactionDay = DateTime.now().day; 
                          // Make sure this day is valid for the current _year and _month of the dashboard
                           if (DateTime(int.parse(transactionMonthYearKey.split('-')[0]), int.parse(transactionMonthYearKey.split('-')[1]), 1).month != DateTime.now().month &&
                               transactionDay > DateTime(int.parse(transactionMonthYearKey.split('-')[0]), int.parse(transactionMonthYearKey.split('-')[1]) + 1, 0).day) {
                                // If adding to a past/future month, and today's day number is invalid for that month, use last day of that month.
                                transactionDay = DateTime(int.parse(transactionMonthYearKey.split('-')[0]), int.parse(transactionMonthYearKey.split('-')[1]) + 1, 0).day;
                           }
                      }
                      
                      // Validate day for the month (_year and _month from parent state)
                        try {
                            DateTime(int.parse(transactionMonthYearKey.split('-')[0]), int.parse(transactionMonthYearKey.split('-')[1]), transactionDay);
                        } catch (e) {
                            setSheetState(() => localErrorText = "Invalid day for the selected month/year.");
                            return;
                        }


                      Map<String, dynamic> dataToSave = {
                        "type": _selectedType == TransactionType.expense ? "expense" : "income",
                        "category": _category, // From parent state
                        "amount": enteredAmount, // Firestore stores positive amount
                        "description": descriptionStr,
                        "date": transactionDay,
                        "monthYear": transactionMonthYearKey,
                        "expenseId": docId, // Keeping "expenseId" for consistency with original code
                        "timestamp": FieldValue.serverTimestamp(),
                      };

                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        setSheetState(() => localErrorText = "User not logged in.");
                        return;
                      }

                      try {
                        await FirebaseFirestore.instance
                            .collection("expenses") // Collection still named "expenses"
                            .doc(currentUser.uid)
                            .collection(transactionMonthYearKey)
                            .doc(docId)
                            .set(dataToSave, SetOptions(merge: isEditing));

                        // Update Local Cache
                        final cacheCollectionKey = '${currentUser.uid}_$transactionMonthYearKey';
                        // Fetch current list, or start with empty if not exists
                        List<expenseModel> cachedMonthTransactions = 
                            (_expenseBox.get(cacheCollectionKey) ?? []).map((e) => e as expenseModel).toList();

                        expenseModel newOrUpdatedModel = expenseModel(
                          id: docId,
                          amount: _selectedType == TransactionType.expense ? -enteredAmount : enteredAmount, // Signed amount for model
                          date: transactionDay,
                          description: descriptionStr.isEmpty ? null : descriptionStr,
                          category: _category,
                          type: _selectedType == TransactionType.expense ? "expense" : "income",
                          timestamp: DateTime.now(), // Use local time for cache, Firestore fetch will get server time
                        );

                        if (isEditing) {
                          int index = cachedMonthTransactions.indexWhere((e) => e.id == docId);
                          if (index != -1) {
                            cachedMonthTransactions[index] = newOrUpdatedModel;
                          } else {
                            cachedMonthTransactions.add(newOrUpdatedModel); // Add if not found (shouldn't happen for edit)
                          }
                        } else {
                          cachedMonthTransactions.add(newOrUpdatedModel);
                        }
                        // Sort cache if desired (e.g., by timestamp)
                        cachedMonthTransactions.sort((a, b) {
                             if(a.timestamp == null && b.timestamp == null) return 0;
                             if(a.timestamp == null) return 1; // nulls last
                             if(b.timestamp == null) return -1;
                             return b.timestamp!.compareTo(a.timestamp!);
                        });
                        await _expenseBox.put(cacheCollectionKey, cachedMonthTransactions);
                        
                        Navigator.pop(modalContext); // Close sheet
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('${_selectedType == TransactionType.expense ? "Expense" : "Income"} ${isEditing ? "updated" : "saved"} successfully!'),
                              backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                        );

                        if (mounted) {
                          // If the operation was for the currently viewed month, refresh its data from cache.
                          // Otherwise, the cache for that other month is updated, and user can navigate to see it.
                          fetchData(transactionMonthYearKey); 
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to save ${_selectedType == TransactionType.expense ? "expense" : "income"}: $e'),
                                backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                          );
                        }
                         print("Error saving transaction: $e");
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}