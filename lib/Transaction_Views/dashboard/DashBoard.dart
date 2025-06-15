import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:moneymanager/Transaction_Views/analysis/View.dart';
import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart'; // Ensure this path is correct and model is Hive-adapted
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/security/uid.dart'; // Ensure userId.uid is available
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
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with AutomaticKeepAliveClientMixin{

  @override
  bool get wantKeepAlive => true;
  // Hive Box Names
  static const String _expenseCacheBoxName = 'monthlyExpensesCache';
  static const String _userSettingsBoxName = 'userSettings';

  int _budget = 0;
  int _avg = 0;
  int _total = 0;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int _pace = 0;

  List<expenseModel> _expenseModels = [];

  String _formattedDate = '';

  bool _isLoading = true;
  bool _doesExist = true;

  late TextEditingController _budgetInputController;
  late TextEditingController _expenseAmountController;
  late TextEditingController _expenseDescriptionController;
  late DraggableScrollableController _draggableController;

  final bool _isOnline = true; // Consider using a connectivity plugin for real-time status

  double _income = 0;

  Box<List<dynamic>> get _expenseBox => Hive.box<List<dynamic>>(_expenseCacheBoxName);
  Box get _settingsBox => Hive.box(_userSettingsBoxName);

  @override
  void initState() {
    super.initState();
    _budgetInputController = TextEditingController();
    _expenseDescriptionController = TextEditingController();
    _expenseAmountController = TextEditingController();
// Initialize based on default type
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
      CategoryIcon(
          itemName: "Food",
          itemIcon: Icon(Icons.food_bank, color: Colors.orange[700])),
      CategoryIcon(
          itemName: "restaurant",
          itemIcon: Icon(Icons.fastfood_outlined, color: Colors.deepOrange[400])),
      CategoryIcon(
          itemName: "Transport",
          itemIcon: Icon(Icons.directions_car_filled_outlined, color: Colors.blue[700])),
      CategoryIcon(
          itemName: "Shopping",
          itemIcon: Icon(Icons.shopping_bag_outlined, color: Colors.purple[700])),
      CategoryIcon(
          itemName: "Bills",
          itemIcon: Icon(Icons.receipt_long_outlined, color: Colors.teal[700])),
      CategoryIcon(
          itemName: "Entertainment",
          itemIcon: Icon(Icons.movie_filter_outlined, color: Colors.red[400])),
      CategoryIcon(
          itemName: "Health",
          itemIcon: Icon(Icons.healing_outlined, color: Colors.green[700])),
      CategoryIcon(
          itemName: "Education",
          itemIcon: Icon(Icons.school_outlined, color: Colors.indigo[700])),
      CategoryIcon(
          itemName: "Others",
          itemIcon: Icon(Icons.category_outlined, color: Colors.grey[700])),
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
    if (!_isOnline && _expenseModels.isEmpty && !_isLoading) {
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
                borderSide: BorderSide(color: theme.apptheme_Black, width: 2),
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
                backgroundColor: theme.apptheme_Black,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
     
      backgroundColor: theme.backgroundColor,
     
      appBar: AppBar(
        backgroundColor: theme.apptheme_Black,
        elevation: 1,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
        title: Text("Finance Dashboard", style: theme.subtitle),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: (){
                Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => AnalysisScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.ease;
                  final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                  },
                ),
                );
            },
            child:Icon(Icons.analytics_outlined)
            ),
            SizedBox(width: 20,)
        ],
      ),
     
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
        heroTag: "expense_fab",
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text("Expense"),
        onPressed: () {
          setState(() {
          });
          _showExpenseInputSheet();
        },
        elevation: 4.0,
          ),
          const SizedBox(width: 18),
          FloatingActionButton.extended(
        heroTag: "income_fab",
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text("Income"),
        onPressed: () {
          setState(() {
          });
          _showIncomeInputSheet();
        },
        elevation: 4.0,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isOnline && _expenseModels.isEmpty && !_isLoading) {
      return _buildOfflineMessage();
    }
    return 
    Column(
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
              color: theme.apptheme_Black.withAlpha(180),
              backgroundColor: Colors.white,
              springAnimationDurationInMilliseconds: 350,
              onRefresh: _refresh,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.apptheme_Black)))
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
                  backgroundColor: theme.apptheme_Black,
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
                _buildSummaryCard("Daily Budget", _budget.toString(), Icons.account_balance_wallet_outlined, theme.apptheme_Black, Colors.black87, onTap: _openBudgetDialog),
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
        if (day % 10 == 1 && day % 100 != 11) {
          daySuffix = "st";
        } else if (day % 10 == 2 && day % 100 != 12) daySuffix = "nd";
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
              ...dayExpenses.map((expense) => _buildExpenseTile(expense)),
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
                         color: (expense.type == "income") ? Colors.green : theme.apptheme_Black))
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
          backgroundColor: categoryIconData.itemIcon.color?.withOpacity(0.12) ?? theme.apptheme_Black.withOpacity(0.12),
          child: IconTheme(
              data: IconThemeData(color: categoryIconData.itemIcon.color ?? theme.apptheme_Black, size: 22),
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

  
  void _confirmDeleteTransaction(expenseModel transaction) {
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
                leading: Icon(Icons.edit_note_rounded, color: theme.apptheme_Black, size: 26),
                title: Text(editTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                //edit edit edit
                onTap: () {
                  Navigator.pop(context);
                 _showTransactionInputSheet(
                    context: context,
                    transactionType: isIncome ? TransactionType.income : TransactionType.expense,
                    categories: isIncome ? _getIncomeCategoriesWithIcons() : _getExpenseCategoriesWithIcons(),
                    formattedDate: _formattedDate,
                    expenseBox: _expenseBox,
                    fetchDataCallback: fetchData,
                    themeColors: SheetThemeColors(
                      backgroundColor: const Color.fromARGB(255, 52, 52, 52),
                      textColor: const Color.fromARGB(255, 200, 200, 200),
                      hintTextColor: Colors.grey[500]!,
                      inputBorderColor: Colors.grey[700]!,
                      focusedInputBorderColor: isIncome ? Colors.greenAccent : theme.apptheme_Black,
                      primaryActionColor: isIncome ? Colors.green : Colors.blue,
                      categorySelectedBackgroundColor: isIncome ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                      categorySelectedIconColor: isIncome ? Colors.green[300]! : Colors.blue,
                      categorySelectedTextColor: isIncome ? Colors.green[300]! : Colors.blue,
                      categoryUnselectedIconColor: Colors.grey[400]!,
                      categoryUnselectedTextColor: Colors.grey[400]!,
                    ),
                    isEditing: true,
                    editedId: expense.id, // Pass the ID of the transaction to edit
                    initialAmount: expense.amount.abs().toString(),
                    initialDescription: expense.description,
                    initialCategory: expense.category,
                    editingDateNum: expense.date.toString(), // Pass the date as a string
                 );
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

///=================================
/// Add/Edit Expense Sheet Content
///=================================

  void _showIncomeInputSheet() {
    _showTransactionInputSheet(
      context: context,
      transactionType: TransactionType.income,
      categories: _getIncomeCategoriesWithIcons(),
      formattedDate: _formattedDate,
      expenseBox: _expenseBox,
      fetchDataCallback: fetchData,

      themeColors: SheetThemeColors(
        backgroundColor: Colors.grey[900]!,
        textColor: Colors.white,
        hintTextColor: Colors.grey[500]!,
        inputBorderColor: Colors.grey[700]!,
        focusedInputBorderColor: Colors.greenAccent,
        primaryActionColor: Colors.green,
        categorySelectedBackgroundColor: Colors.green.withOpacity(0.2),
        categorySelectedIconColor: Colors.green[300]!,
        categorySelectedTextColor: Colors.green[300]!,
        categoryUnselectedIconColor: Colors.grey[400]!,
        categoryUnselectedTextColor: Colors.grey[400]!,
      ),
    );
  }

  void _showExpenseInputSheet() {
  _showTransactionInputSheet(
    context: context,
    transactionType: TransactionType.expense,
    categories: _getExpenseCategoriesWithIcons(),
    formattedDate: _formattedDate,
    expenseBox: _expenseBox,
    fetchDataCallback: fetchData,
    themeColors: SheetThemeColors(
      backgroundColor: const Color.fromARGB(255, 85, 85, 85), // Dark background (already set)
      textColor: Colors.white, // Keep text white as it should be visible on dark grey
      hintTextColor: Colors.grey[400]!, // Change hint text to a lighter grey
      inputBorderColor: Colors.grey[600]!, // Change border to a visible grey
      focusedInputBorderColor: theme.apptheme_Black, // Keep as is
      primaryActionColor: Colors.deepPurple,
      categorySelectedBackgroundColor: theme.apptheme_Black.withOpacity(0.2),
      categorySelectedIconColor: theme.apptheme_Black,
      categorySelectedTextColor: const Color.fromARGB(255, 196, 43, 216),
      categoryUnselectedIconColor: Colors.grey[400]!,
      categoryUnselectedTextColor: Colors.grey[400]!,
    ),
  );
}

void _showTransactionInputSheet({
  required BuildContext context,
  required TransactionType transactionType,
  required List<CategoryIcon> categories,
  required String formattedDate,
  required Box expenseBox,
  required Future<void> Function(String) fetchDataCallback,
  required SheetThemeColors themeColors,
  bool isEditing = false,
  String? editedId,
  String? initialAmount,
  String? initialDescription,
  String? initialCategory,
  String? editingDateNum,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) { // controller is DraggableScrollableController
          return _TransactionInputSheetContent(
            scrollController: controller, // Pass the controller for ListView
            transactionType: transactionType,
            categories: categories,
            formattedDate: formattedDate,
            expenseBox: expenseBox,
            fetchDataCallback: fetchDataCallback,
            themeColors: themeColors,
            isEditing: isEditing,
            editedId: editedId,
            initialAmount: initialAmount,
            initialDescription: initialDescription,
            initialCategory: initialCategory,
            editingDateNum: editingDateNum,
            // The parent's _selectedType state is passed implicitly via transactionType for the sheet's own logic
          );
        },
      );
    },
  );
}

}

class _TransactionInputSheetContent extends StatefulWidget {
  final ScrollController scrollController;
  final TransactionType transactionType;
  final List<CategoryIcon> categories;
  final String formattedDate; // Parent's current month-year context ("YYYY-MM")
  final Box expenseBox;
  final Future<void> Function(String) fetchDataCallback;
  final SheetThemeColors themeColors;

  // Editing parameters
  final bool isEditing;
  final String? editedId;
  final String? initialAmount;
  final String? initialDescription;
  final String? initialCategory;
  final String? editingDateNum; // Day of month as string when editing


  const _TransactionInputSheetContent({
    required this.scrollController,
    required this.transactionType,
    required this.categories,
    required this.formattedDate,
    required this.expenseBox,
    required this.fetchDataCallback,
    required this.themeColors,
    this.isEditing = false,
    this.editedId,
    this.initialAmount,
    this.initialDescription,
    this.initialCategory,
    this.editingDateNum,
  });

  @override
  _TransactionInputSheetContentState createState() => _TransactionInputSheetContentState();
}

class _TransactionInputSheetContentState extends State<_TransactionInputSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  String? _selectedCategoryName;
  String? _localErrorText;
  bool _isSaving = false;

  // This controller was in your original snippet. Its exact usage for scroll reset
  // upon category error was specific. Here, it's a state variable.
  // If it was for the main DraggableScrollableSheet, direct manipulation is complex.
  // For now, it's distinct.
  late DraggableScrollableController _sheetInternalDraggableController;
 // late String _defaultCategoryForType;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount);
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _selectedCategoryName = widget.initialCategory;

    _sheetInternalDraggableController = DraggableScrollableController();
     if (widget.isEditing && widget.initialCategory != null) {
      _selectedCategoryName = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _sheetInternalDraggableController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form validation failed
    }
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _localErrorText = ""; // Clear previous errors
    });

    final String amountStr = _amountController.text.trim();
    final String descriptionStr = _descriptionController.text.trim();
    final double? enteredAmount = double.tryParse(amountStr);

    if (enteredAmount == null || enteredAmount <= 0) {
      setState(() {
        _localErrorText = "Please enter a valid positive amount.";
        _isSaving = false;
      });
      return;
    }

    // Validate category
    bool categoryIsValid = widget.categories.any((cat) => cat.itemName == _selectedCategoryName);
    if (_selectedCategoryName == null || _selectedCategoryName!.isEmpty || !categoryIsValid) {
      setState(() {
        _localErrorText = "Please select a valid category.";
        _selectedCategoryName = null; // Reset category selection
        _isSaving = false;
      });
      return;
    }
    
    setState(() => _localErrorText = "");

    String docId = widget.isEditing && widget.editedId != null ? widget.editedId! : const Uuid().v4();
    
    // Use widget.formattedDate for the month/year context from the parent.
    String transactionMonthYearKey = widget.formattedDate;
    int transactionDay;

    if (widget.isEditing && widget.editingDateNum != null && widget.editingDateNum!.isNotEmpty) {
        transactionDay = int.tryParse(widget.editingDateNum!) ?? DateTime.now().day;
    } else {
        DateTime now = DateTime.now();
        DateTime currentDashboardDate = DateTime(
            int.parse(transactionMonthYearKey.split('-')[0]),
            int.parse(transactionMonthYearKey.split('-')[1]),
            1 // Use 1st day to compare month and year
        );

        // If adding to the currently viewed month (on dashboard) use today's day.
        // If adding to a past/future month, use the 1st day of that month, or last if today's day is invalid.
        if (currentDashboardDate.year == now.year && currentDashboardDate.month == now.month) {
            transactionDay = now.day;
        } else {
            // Adding to a different month than current real-time month.
            // Default to 1st day of that month, or ensure 'now.day' is valid for that month.
            int daysInSelectedMonth = DateTime(currentDashboardDate.year, currentDashboardDate.month + 1, 0).day;
            if (now.day > daysInSelectedMonth) {
                transactionDay = daysInSelectedMonth; // Use last day of that target month
            } else {
                transactionDay = now.day; // Use current day number if valid
            }
            // A common choice is to default to the 1st day of a past/future month
            // transactionDay = 1; // Or let user pick via a DatePicker.
        }
    }
    
    // Validate day for the month
    try {
        DateTime(int.parse(transactionMonthYearKey.split('-')[0]), int.parse(transactionMonthYearKey.split('-')[1]), transactionDay);
    } catch (e) {
        setState(() {
            _localErrorText = "Invalid day ($transactionDay) for the selected month/year.";
            _isSaving = false;
        });
        return;
    }

    Map<String, dynamic> dataToSave = {
      "type": widget.transactionType == TransactionType.expense ? "expense" : "income",
      "category": _selectedCategoryName!,
      "amount": enteredAmount, // Firestore stores positive amount
      "description": descriptionStr,
      "date": transactionDay, // Day of the month
      "monthYear": transactionMonthYearKey, // "YYYY-MM"
      "expenseId": docId, // Keeping "expenseId" for consistency
      "timestamp": FieldValue.serverTimestamp(),
    };

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _localErrorText = "User not logged in.";
        _isSaving = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection("expenses") // Collection still named "expenses"
          .doc(currentUser.uid)
          .collection(transactionMonthYearKey)
          .doc(docId)
          .set(dataToSave, SetOptions(merge: widget.isEditing));

      // Update Local Cache (Hive)
      // Ensure _expenseBox is valid and open before using.
      // The key for Hive is uid_YYYY-MM
      final cacheCollectionKey = '${currentUser.uid}_$transactionMonthYearKey';
      
      // Type casting: make sure the items in the box are indeed expenseModel or handle potential errors.
      List<dynamic> rawCachedList = widget.expenseBox.get(cacheCollectionKey) ?? [];
      List<expenseModel> cachedMonthTransactions = [];
      if (rawCachedList.isNotEmpty) {
          // Check type of first element to be safer, or ensure adapter is registered and box is typed
          if (rawCachedList.first is expenseModel) {
            cachedMonthTransactions = rawCachedList.cast<expenseModel>().toList();
          } else {
            // Handle cases where items might not be expenseModel (e.g. migration, error)
            // For now, we'll assume they are or clear if not.
            print("Warning: Hive box contained items not of type expenseModel. Clearing for this key.");
            // Or attempt conversion if possible.
          }
      }


      expenseModel newOrUpdatedModel = expenseModel(
        id: docId,
        amount: widget.transactionType == TransactionType.expense ? -enteredAmount : enteredAmount, // Signed amount for model
        date: transactionDay,
        description: descriptionStr.isEmpty ? null : descriptionStr,
        category: _selectedCategoryName!,
        type: widget.transactionType == TransactionType.expense ? "expense" : "income",
        timestamp: DateTime.now(), // Local time for cache, Firestore gets server time
        monthYear: transactionMonthYearKey,
      );

      if (widget.isEditing) {
        int index = cachedMonthTransactions.indexWhere((e) => e.id == docId);
        if (index != -1) {
          cachedMonthTransactions[index] = newOrUpdatedModel;
        } else {
          // Should not happen for edit if item was loaded from cache, but as a fallback:
          cachedMonthTransactions.add(newOrUpdatedModel);
        }
      } else {
        cachedMonthTransactions.add(newOrUpdatedModel);
      }
      
      // Sort cache (e.g., by timestamp descending)
      cachedMonthTransactions.sort((a, b) {
          if(a.timestamp == null && b.timestamp == null) return 0;
          if(a.timestamp == null) return 1; // nulls last
          if(b.timestamp == null) return -1;
          return b.timestamp!.compareTo(a.timestamp!);
      });
      await widget.expenseBox.put(cacheCollectionKey, cachedMonthTransactions);
      
      Navigator.pop(context); // Close sheet (uses the modal's context)
      
      ScaffoldMessenger.of(context).showSnackBar( // Use this.context if it's the sheet's context
        SnackBar(
          content: Text('${widget.transactionType == TransactionType.expense ? "Expense" : "Income"} ${widget.isEditing ? "updated" : "saved"} successfully!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );

      // If the operation was for the currently viewed month, refresh its data from cache.
      widget.fetchDataCallback(transactionMonthYearKey);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ${widget.transactionType == TransactionType.expense ? "expense" : "income"}: $e'),
            backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
        setState(() {
          _localErrorText = "Error: $e";
          _isSaving = false;
        });
      }
      print("Error saving transaction: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeColors = widget.themeColors;
    String title = widget.transactionType == TransactionType.income ? "Add Income" : "Add Expense";
    if (widget.isEditing) {
      title = widget.transactionType == TransactionType.income ? "Edit Income" : "Edit Expense"; // Corrected assignment
    }


    return Container(
      decoration: BoxDecoration(
        color: themeColors.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: ListView( // Use ListView with the DraggableScrollableSheet's controller
          controller: widget.scrollController,
          children: <Widget>[
            // Handlebar for draggable sheet (optional visual cue)
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Amount Field
            TextFormField(
              controller: _amountController,
              style: TextStyle(fontWeight: FontWeight.bold,color: const Color.fromARGB(255, 48, 48, 48)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Amount",
                labelStyle: TextStyle(color: themeColors.hintTextColor),
                hintText: "0.00",
                hintStyle: TextStyle(color: themeColors.hintTextColor.withOpacity(0.7)),
                prefixIcon: Icon(Icons.attach_money, color: themeColors.hintTextColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColors.inputBorderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColors.focusedInputBorderColor, width: 2)),
                errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.shade100)),
                focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.shade100, width: 2)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final double? amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid positive amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description Field (Optional)
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(fontWeight: FontWeight.bold,color: const Color.fromARGB(255, 48, 48, 48)),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Description (Optional)",
                labelStyle: TextStyle(color: themeColors.hintTextColor),
                hintText: "e.g., Lunch, Salary for May",
                hintStyle: TextStyle(color: themeColors.hintTextColor.withOpacity(0.7)),
                prefixIcon: Icon(Icons.description_outlined, color: themeColors.hintTextColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColors.inputBorderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColors.focusedInputBorderColor, width: 2)),
              ),
            ),
            const SizedBox(height: 25),

            // Category Selector
            Text(
              "Select Category",
              style: TextStyle(color: themeColors.textColor.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: widget.categories.map((category) {
                final bool isSelected = _selectedCategoryName == category.itemName;
                final originalIcon = category.itemIcon;
                final iconColor = isSelected ? themeColors.categorySelectedIconColor : (originalIcon.color ?? themeColors.categoryUnselectedIconColor);
                final textColor = isSelected ? themeColors.categorySelectedTextColor : themeColors.categoryUnselectedTextColor;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryName = category.itemName;
                      _localErrorText = null; // Clear category error on new selection
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? themeColors.categorySelectedBackgroundColor : themeColors.inputBorderColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18.0),
                      border: Border.all(
                        color: isSelected ? themeColors.primaryActionColor.withOpacity(0.5) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconTheme(
                            data: IconThemeData(color: iconColor, size: 18),
                            child: originalIcon, // Use the pre-defined icon directly
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.itemName,
                          style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.w600: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Error Text Display
            if (_localErrorText != null && _localErrorText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0, top: 5.0),
                child: Text(
                  _localErrorText!,
                  style: TextStyle(color: Colors.redAccent[100], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            // Submit Button
            _isSaving
                ? Center(child: CircularProgressIndicator(color: themeColors.primaryActionColor))
                : ElevatedButton.icon(
                    icon: Icon(widget.isEditing ? Icons.check_circle_outline : Icons.add_circle_outline, color: Colors.white),
                    label: Text(widget.isEditing ? 'Update' : 'Save', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColors.primaryActionColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _saveTransaction,
                  ),
            const SizedBox(height: 20), // Padding for keyboard
          ],
        ),
      ),
    );
  }
}

class SheetThemeColors {
  final Color backgroundColor;
  final Color textColor;
  final Color hintTextColor;
  final Color inputBorderColor;
  final Color focusedInputBorderColor;
  final Color primaryActionColor;
  final Color categorySelectedBackgroundColor;
  final Color categorySelectedIconColor;
  final Color categorySelectedTextColor;
  final Color categoryUnselectedIconColor;
  final Color categoryUnselectedTextColor;


  SheetThemeColors({
    required this.backgroundColor,
    required this.textColor,
    required this.hintTextColor,
    required this.inputBorderColor,
    required this.focusedInputBorderColor,
    required this.primaryActionColor,
    required this.categorySelectedBackgroundColor,
    required this.categorySelectedIconColor,
    required this.categorySelectedTextColor,
    required this.categoryUnselectedIconColor,
    required this.categoryUnselectedTextColor,
  });
}
