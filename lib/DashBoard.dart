import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting (month name)
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:moneymanager/feedback/feedback.dart';
import 'package:moneymanager/main.dart';
import 'package:moneymanager/model/expenseModel.dart'; // Assuming your model is here
import 'package:moneymanager/showUpdate.dart';
import 'package:moneymanager/themeColor.dart'; // Provides 'theme'
import 'package:moneymanager/uid/uid.dart';     // Provides 'userId'
import 'package:uuid/uuid.dart';

// Placeholder for CategoryIcon data class if not defined elsewhere
// You should have this defined, perhaps in your expenseModel.dart or a separate file.
class CategoryIcon {
  final String itemName;
  final Icon itemIcon; // Storing the Icon widget directly

  CategoryIcon({required this.itemName, required this.itemIcon});
}
enum TransactionType { expense, income }

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final ShowUpdate _updateChecker = ShowUpdate();
  String _category = "Food"; // Default category for new expenses
  int _budget = 0;
  List<expenseModel> _expenseModels = [];
  int _avg = 0;
  int _total = 0;
  String _formattedDate = ''; // Format: YYYY-MM
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  bool _isLoading = true;
  bool _doesExist = true; // True if expenses exist for the month
  int _pace = 0; // Saving or overspending
  TransactionType _selectedType = TransactionType.expense;

  late TextEditingController _budgetInputController;
  late TextEditingController _expenseAmountController;
  late TextEditingController _expenseDescriptionController;
  late DraggableScrollableController _draggableController;

  String _editedId = ''; // ID of the expense being edited
  String _editingDateNum = ''; // Day number (as String) for editing

  bool _isOnline = true;
  late List<CategoryIcon> _categoryIcons;

    

  @override
  void initState() {
    super.initState();
 _budgetInputController = TextEditingController();
 _draggableController = DraggableScrollableController();
 _expenseDescriptionController = TextEditingController();
 _expenseAmountController = TextEditingController();
    _categoryIcons = _getExpenseCategoriesWithIcons(); // Initialize categories
    _performUpdateCheck();
    _initializeDateAndFetchData();

  }

  @override
  void dispose() {
    _draggableController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    super.dispose();
  }



  List<CategoryIcon> _getExpenseCategoriesWithIcons() {
    // Replace this with your actual category data and icons
    // Ensure colors match your theme.shiokuriBlue or are appropriate
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
  // Define your income categories and icons
  // Use appropriate icons and ensure colors fit your theme
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

  void _performUpdateCheck() {
    _updateChecker.checkUpdate(context, (currentVersion, newVersion) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              title: const Text("Update Available", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Text("A newer version ($newVersion) is available.\nCurrent Version: $currentVersion"),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700], padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
                  child: const Text("Later"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.shiokuriBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
                  child: const Text("Update Now"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _updateChecker.launchAppStore();
                  },
                ),
              ],
            );
          },
        );
      }
    });
  }

  Future<void> fetchData(String dateToFetch) async {
    if (!_isOnline && _expenseModels.isEmpty) { // Only show full block if truly no data and offline
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _formattedDate = dateToFetch;
      // Update _year and _month from dateToFetch
      var parts = dateToFetch.split('-');
      _year = int.parse(parts[0]);
      _month = int.parse(parts[1]);
    });

    try {
      DocumentSnapshot budgetDoc = await FirebaseFirestore.instance
          .collection("budget")
          .doc(userId.uid)
          .get();
      if (mounted) {
        setState(() {
          if (budgetDoc.exists) {
            _budget = (budgetDoc.data() as Map<String, dynamic>)['budget'] ?? 0;
          } else {
            _budget = 0;
          }
        });
      }


      QuerySnapshot expensesSnapshot = await FirebaseFirestore.instance
          .collection("expenses")
          .doc(userId.uid)
          .collection(dateToFetch)
          .orderBy("date", descending: true) // Sort by day of the month
          .get();

      if (mounted) {
        _expenseModels.clear();
        for (var doc in expensesSnapshot.docs) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey("amount") && data.containsKey("date")) {
            _expenseModels.add(expenseModel(
              amount: (data["amount"] as num).toDouble(),
              date: (data["date"] as num).toInt(),
              id: doc.id,
              description: data["description"] as String?,
              category: data["category"] as String?,
              type: data["type"] as String?,
            ));
          }
        }
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
          SnackBar(content: Text("Error fetching data: $e"), backgroundColor: Colors.redAccent),
        );
      }
      print("Error fetching data: $e");
    }
  }

  void _calculateFinancialSummary() {
    if (!mounted) return;

    if (_expenseModels.isEmpty) {
      setState(() {
        _avg = 0;
        int daysInCurrentViewMonth = DateTime(_year, _month + 1, 0).day;
        _pace = _budget * daysInCurrentViewMonth; // Full budget remaining for the month
      });
      return;
    }

    double totalExpenses = _expenseModels.fold(0.0, (sum, item) => sum + item.amount);
    
    // Since expenses are sorted by date (day of month) descending, the first is the latest.
    int latestExpenseDayInMonth = _expenseModels.first.date;

    int daysPassedForCalc;
    DateTime today = DateTime.now();

    if (_year == today.year && _month == today.month) { // Current actual month
      daysPassedForCalc = (latestExpenseDayInMonth > today.day) ? latestExpenseDayInMonth : today.day;
      daysPassedForCalc = (daysPassedForCalc > today.day) ? today.day : daysPassedForCalc; // Cap at today
    } else { // Viewing a past or future month
      daysPassedForCalc = latestExpenseDayInMonth;
    }
    daysPassedForCalc = daysPassedForCalc > 0 ? daysPassedForCalc : 1; // Avoid division by zero

    setState(() {
      _total = totalExpenses.round();
      _avg = (totalExpenses / daysPassedForCalc).round();
      double idealSpendingToDate = _budget * daysPassedForCalc.toDouble();
      _pace = (idealSpendingToDate - totalExpenses).round();
    });
  }

  Future<void> _refresh() async {
    await fetchData(_formattedDate);
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
                backgroundColor: theme.shiokuriBlue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              ),
              child: const Text("Save", style: TextStyle(fontSize: 16)),
              onPressed: () async {
                final int? newBudget = int.tryParse(_budgetInputController.text);
                if (newBudget != null && newBudget >= 0) {
                  try {
                    await FirebaseFirestore.instance.collection("budget").doc(userId.uid).set({"budget": newBudget});
                    if (mounted) {
                      setState(() => _budget = newBudget);
                      _calculateFinancialSummary(); // Recalculate pace
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Daily budget updated to RM $newBudget.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if(mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update budget: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                } else {
                   if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid budget amount.'), backgroundColor: Colors.orangeAccent),
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

    // In _DashboardState
  void _showAddEditExpenseSheet({expenseModel? expenseToEdit}) {
    bool isEditing = expenseToEdit != null;
    
    // Use setState to update the parent state variables before showing the sheet
    setState(() {
      if (isEditing) {
        // Editing mode - assumes it's always an expense based on original code
        _selectedType = TransactionType.expense; // Editing only supports expense for now
        _editedId = expenseToEdit.id;
        _expenseAmountController.text = expenseToEdit.amount.toStringAsFixed(2);
        _expenseDescriptionController.text = expenseToEdit.description ?? '';
        _category = expenseToEdit.category ?? 'Others'; // Ensure this category exists in expense list
        _editingDateNum = expenseToEdit.date.toString(); // Assuming 'date' stores the day number
      } else {
        _selectedType = TransactionType.expense; // Default to expense when adding
        _editedId = '';
        _expenseAmountController.clear();
        _expenseDescriptionController.clear();
        _category = "Food"; // Default expense category
        _editingDateNum = DateTime.now().day.toString();
      }
    });

    showModalBottomSheet(
      
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Important for custom shape
      // Pass isEditing status; _selectedType and _category are read from parent state
      builder: (context) => _buildAddEditExpenseSheetContent(isEditing: isEditing),
    );
  } 
  
  @override
  Widget build(BuildContext context) {
    print("Dashboard build method called");
    return Scaffold(
      // Make sure you have access to your theme object, e.g., 'theme.shiokuriBlue'
      // and 'theme.backgroundColor' if you intend to use it (though for dark theme, we'll override).

      drawer: GestureDetector(
        
        // This GestureDetector makes the entire drawer surface tappable to close itself.
        // This is not standard behavior (usually, tapping outside or an item closes it).
        // If you prefer standard behavior, you might remove this outer GestureDetector
        // and let the Scaffold handle closing the drawer when the scrim is tapped.
        onTap: () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop(); // Close drawer on tap of any part of it
          }
        },
        child: Drawer(
          backgroundColor: const Color(0xFF1A1A1A), // A deep, modern dark gray
          child: SafeArea( // Ensures content isn't obscured by system UI (notches, etc.)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Custom Drawer Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  decoration: BoxDecoration(
                    // Example of a subtle gradient or different shade for header
                    color: theme.shiokuriBlue.withOpacity(0.15), // Using your theme's accent color subtly
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.shiokuriBlue,
                        child: const Icon(
                          Icons.account_balance_wallet_rounded, // Example: Finance App Icon
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Finance Planner", // Replace with your App's Name
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Version 1.6.0", // Replace with dynamic version later if needed
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8.0), // Add some padding at the top of the list
                    children: [
                      _buildDrawerItem(
                        context: context, // Pass context for Navigator & SnackBar
                        icon: Icons.exit_to_app_outlined,
                        text: 'Sign Out',
                        accentColor: theme.shiokuriBlue,
                        onTap: () async{
                          Navigator.pop(context); // Close drawer first
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
                            isScrollControlled: true, // Important for keyboard to not cover fields
                            backgroundColor: Colors.transparent, // For custom shape and background
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
                            ),
                            builder: (BuildContext modalContext) {
                              return FeedbackForm(); // The actual form content
                            },
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
                                    applicationVersion: '1.6.0',
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

                // Optional Footer Text (e.g., a small quote or branding)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
                  child: Text(
                    "Your finances, simplified.", // Or any other footer text
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: theme.backgroundColor, // Lighter background
      appBar: AppBar(
        backgroundColor: theme.shiokuriBlue,
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        title: Text(
          "Finance Dashboard",
          style: theme.subtitle,
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.shiokuriBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_outlined),
        label: const Text("New Expense"),
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
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white, // Changed list background to white
              borderRadius:  BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: ClipRRect( // Ensure pull to refresh respects border radius
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35), bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
                child: LiquidPullToRefresh(
                color: theme.shiokuriBlue.withAlpha(180),
                backgroundColor: Colors.white,
                springAnimationDurationInMilliseconds: 350,
                onRefresh: _refresh,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.shiokuriBlue)))
                    : _doesExist
                        ? _buildExpenseList()
                        : _buildNoRecordsMessage(isEmpty: true), // Pass flag
              ),
            ),
          ),
        ),
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
                backgroundColor: theme.shiokuriBlue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
              onPressed: () {
                 if(_isOnline) fetchData(_formattedDate); // Re-fetch if connection is now on
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color iconColor, Color valueColor, {VoidCallback? onTap}) {
    return InkWell( // Use InkWell for tap effect
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
      padding: const EdgeInsets.fromLTRB(0,12.0,0,8.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 120), // Limit height for horizontal list
        child:ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildSummaryCard("Daily Budget", _budget.toString(), Icons.account_balance_wallet_outlined, theme.shiokuriBlue, Colors.black87, onTap: _openBudgetDialog),
              const SizedBox(width: 10),
              _buildSummaryCard("Avg / Day", _avg.toString(), Icons.data_usage_rounded, Colors.orangeAccent.shade700, Colors.black87),
              const SizedBox(width: 10),
              _buildSummaryCard('total expense', _total.toString(), Icons.monetization_on, Colors.blue, Colors.black),
              const SizedBox(width: 10),
              _buildPaceCard(),
            ],
          ))
    );
  }

  Widget _buildMonthNavigator() {
    String monthName = DateFormat('MMMM yyyy').format(DateTime(_year, _month)); // Full month name and year
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.foregroundColor, size: 20),
            onPressed: () {
              setState(() {
                _month--;
                if (_month == 0) { _month = 12; _year--; }
              });
              fetchData("$_year-${_month.toString().padLeft(2, '0')}");
            },
          ),
          Text(monthName, style: theme.normal),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, color: theme.foregroundColor, size: 20),
            onPressed: () {
              setState(() {
                _month++;
                if (_month == 13) { _month = 1; _year++; }
              });
              fetchData("$_year-${_month.toString().padLeft(2, '0')}");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    Map<int, List<expenseModel>> groupedExpenses = {};
    for (var expense in _expenseModels) {
      (groupedExpenses[expense.date] ??= []).add(expense);
    }
    var sortedDays = groupedExpenses.keys.toList()..sort((a, b) => b.compareTo(a)); // Days sorted descending

    return ListView.separated(
      padding: const EdgeInsets.only(left:10, right:10, top: 5, bottom: 85), // Adjusted padding
      itemCount: sortedDays.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0), // No separator, card margins will handle
      itemBuilder: (context, dayIndex) {
        int day = sortedDays[dayIndex];
        List<expenseModel> dayExpenses = groupedExpenses[day]!;
        String daySuffix = "th";
        if (day == 1 || day == 21 || day == 31) {daySuffix = "st";}
        else if (day == 2 || day == 22) {daySuffix = "nd";}
        else if (day == 3 || day == 23) {daySuffix = "rd";}

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18.0, top: 10.0, bottom: 6.0),
                child: Text(
                  "$day$daySuffix ${DateFormat('MMM').format(DateTime(_year, _month, day))}", // e.g., 1st May
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
    final categoryIconData = _categoryIcons.firstWhere(
        (iconData) => iconData.itemName.toLowerCase() == (expense.category?.toLowerCase() ?? ''),
        orElse: () => CategoryIcon(itemName: "Others", itemIcon: Icon(Icons.label_outline_rounded, color: theme.shiokuriBlue))
    );

    return Card(
      elevation: 1.0, // Subtle elevation
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryIconData.itemIcon.color?.withOpacity(0.12) ?? theme.shiokuriBlue.withOpacity(0.12),
          child: IconTheme(data: IconThemeData(color: categoryIconData.itemIcon.color ?? theme.shiokuriBlue, size: 22), child: categoryIconData.itemIcon),
        ),
        title: Text(
          expense.description != null && expense.description!.isNotEmpty ? expense.description! : (expense.category ?? "Expense"),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
            expense.type == "expense" || expense.type == null ?
            "RM - ${expense.amount.toStringAsFixed(2)}" : "RM + ${(expense.amount).toStringAsFixed(2)}",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500)
        ),
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
      MaterialPageRoute(builder: (context) => UserAuthScreen()), // Replace AuthScreen() with your actual screen widget
      (Route<dynamic> route) => false,
    );
    // Optionally, show a success message (though navigating away might be enough)
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Signed out successfully.'),
    //     backgroundColor: Colors.green,
    //   ),
    // );

  } on FirebaseAuthException catch (e) {
    // If there was a loading indicator, pop it
    // if (Navigator.canPop(context)) {
    //   Navigator.pop(context); // Pop loading dialog
    // }
    
    print('Failed to sign out: ${e.message}'); // Log the error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to sign out: ${e.message ?? "Unknown error"}'),
        backgroundColor: Colors.redAccent,
      ),
    );
  } catch (e) {
    // If there was a loading indicator, pop it
    // if (Navigator.canPop(context)) {
    //   Navigator.pop(context); // Pop loading dialog
    // }

    print('An unexpected error occurred during sign out: $e'); // Log the error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('An unexpected error occurred. Please try again.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

  void _showExpenseOptionsSheet(expenseModel expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // For custom shape
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
          ),
          padding: const EdgeInsets.symmetric(vertical:15, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container( width: 45, height: 5, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal:10.0),
                child: Text(
                  expense.description != null && expense.description!.isNotEmpty ? expense.description! : "Expense Details",
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
               Text(
                "RM ${expense.amount.toStringAsFixed(2)}  •  Category: ${expense.category ?? 'N/A'}",
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: Colors.grey[200]),
              ListTile(
                leading: Icon(Icons.edit_note_rounded, color: theme.shiokuriBlue, size: 26),
                title: const Text('Edit Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEditExpenseSheet(expenseToEdit: expense);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              ),
              ListTile(
                leading: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 26),
                title: const Text('Delete Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  _confirmDeleteExpense(expense);
                },
                 contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              ),
              const SizedBox(height: 10), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteExpense(expenseModel expense) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "${expense.description != null && expense.description!.isNotEmpty ? expense.description : "this expense"}"? This action cannot be undone.'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete', style: TextStyle(fontSize: 16, fontWeight:FontWeight.bold)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await FirebaseFirestore.instance.collection("expenses").doc(userId.uid).collection(_formattedDate).doc(expense.id).delete();
                  if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense deleted successfully.'), backgroundColor: Colors.green),
                    );
                    fetchData(_formattedDate);
                  }
                } catch (e) {
                   if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete expense: $e'), backgroundColor: Colors.redAccent),
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

  // Add this method inside your _DashboardState class

Widget _buildDrawerItem({
  required BuildContext context, // Added context
  required IconData icon,
  required String text,
  required GestureTapCallback onTap,
  required Color accentColor,
}) {
  return ListTile(
    leading: Icon(icon, color: theme.foregroundColor, size: 24),
    title: Text(
      text,
      style: TextStyle(
        fontSize: 15.5, // Slightly adjusted size
        color: Colors.white.withOpacity(0.87),
        fontWeight: FontWeight.w500,
      ),
    ),
    onTap: onTap,
    horizontalTitleGap: 12.0, // Gap between leading icon and title
    contentPadding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0), // Adjusted padding
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Subtle shape for tap feedback area
    hoverColor: Colors.white.withOpacity(0.05),
    splashColor: accentColor.withOpacity(0.1),
  );
}

  Widget _buildNoRecordsMessage({bool isEmpty = false}) {
    String message = isEmpty
        ? 'No expenses recorded for ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}.'
        : 'Pull down to refresh or try again later.';
    String subMessage = isEmpty
        ? "Tap '+' to add a new expense and get started!"
        : 'Could not load records at this time.';

    return LayoutBuilder( // Ensures ListView can work with LiquidPullToRefresh when content is small
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Make it scrollable for pull-to-refresh
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight), // Take full height
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
      }
    );
  }


  Widget _buildAddEditExpenseSheetContent({required bool isEditing}) {
    final theme = Theme.of(context);
    // Placeholder for shiokuriBlue if theme object doesn't directly have it
    final Color primarySheetColor = theme.colorScheme.primary; // Or your theme.shiokuriBlue

    // Get category lists
    final List<CategoryIcon> expenseCategories = _getExpenseCategoriesWithIcons();
    final List<CategoryIcon> incomeCategories = _getIncomeCategoriesWithIcons();

    String localErrorText = ""; // Local error text for the sheet

    // Use StatefulBuilder to manage the sheet's internal UI updates
    // (like error text visibility) without rebuilding the whole dashboard
    return StatefulBuilder(
      builder: (BuildContext sheetContext, StateSetter setSheetState) { // <-- setSheetState を取得

        // Determine current list based on parent state's _selectedType
        final List<CategoryIcon> currentCategories =
            _selectedType == TransactionType.expense ? expenseCategories : incomeCategories;

        // Find the default category for the current type
        final String defaultCategory = _selectedType == TransactionType.expense ? "Food" : "Salary";

        // Function to handle category selection - updates parent state AND sheet state
        void selectCategoryAndUpdateState(String newCategory) {
          if (_category != newCategory) { // カテゴリが実際に変更された場合のみ更新
            // 親ウィジェットのsetStateを呼び出して_categoryを更新
            setState(() { 
              _category = newCategory;
            });
            // StatefulBuilderのsetSheetStateを呼び出して、シート内のUIを更新
            // これにより、GridViewが再描画され、isSelectedが正しく評価されます。
            setSheetState(() {
              // ここで変更するローカルな状態変数はないが、UIの再描画をトリガーする
            });
          }
        }

        // Function to handle type selection - updates parent state
        void selectTypeAndUpdateState(int index) {
          print('switching tab');
          TransactionType newType = index == 0 ? TransactionType.expense : TransactionType.income;
          if (_selectedType != newType) {
            setState(() { // Use parent state's setState
              _draggableController.dispose();
              _draggableController = DraggableScrollableController();
              
              _selectedType = newType;
              _category = _selectedType == TransactionType.expense ? "Food" : "Salary";
              localErrorText = "";
              
              setSheetState((){}); // Update sheet UI if needed (like error text)
            });
          }
        }

        // Build the sheet content
        return DraggableScrollableSheet(
          key: ValueKey(isEditing ? _editedId : _selectedType.toString()),
          controller: _draggableController,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (modalContext, scrollController) {
            return Container(
              // ... (decoration, padding, etc. は既存のまま)
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, spreadRadius: 1)],
              ),
              padding: EdgeInsets.only(
                left: 22, right: 22, top: 12,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20
              ),
              child: ListView(
                controller: scrollController,
                children: <Widget>[
                  Center(child: Container(width: 45, height: 5, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),

                  // ... (以降のウィジェットツリーは既存のまま)
                  // Dynamic Title
                  Text(
                    isEditing
                        ? 'Edit Expense'
                        : (_selectedType == TransactionType.expense ? 'Add New Expense' : 'Add New Income'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primarySheetColor),
                  ),
                  const SizedBox(height: 15),

                  // Toggle Buttons for Type Selection (only show when ADDING)
                  if (!isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: ToggleButtons(
                          isSelected: [
                            _selectedType == TransactionType.expense,
                            _selectedType == TransactionType.income,
                          ],
                          onPressed: selectTypeAndUpdateState, // 修正済みの関数を使用
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
                  const SizedBox(height: 15),

                  // Amount TextField
                  TextField(
                    controller: _expenseAmountController,
                    // ... (既存のプロパティ)
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

                  // Description TextField
                  TextField(
                    controller: _expenseDescriptionController,
                    // ... (既存のプロパティ)
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

                  // Selected Category Text
                  Text('Selected Category: $_category', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                  const SizedBox(height: 12),
                  
                  // Category GridView
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                    child: GridView.builder(
                      physics: const ClampingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10.0,
                        mainAxisSpacing: 10.0,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: currentCategories.length,
                      itemBuilder: (context, index) {
                        final item = currentCategories[index];
                        bool isSelected = _category == item.itemName;
                        Color itemColor = _selectedType == TransactionType.expense
                            ? primarySheetColor
                            : (item.itemIcon is Icon ? (item.itemIcon as Icon).color ?? Colors.green : Colors.green);

                        return GestureDetector(
                          onTap: () => selectCategoryAndUpdateState(item.itemName), // 修正済みの関数を使用
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
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Error Text Area
                  if (localErrorText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
                      child: Text(localErrorText, style: const TextStyle(color: Colors.redAccent, fontSize: 14.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 25),

                  // Save/Update Button
                  ElevatedButton.icon(
                    // ... (既存のプロパティとonPressed内のロジック)
                    icon: Icon(
                      isEditing
                          ? Icons.check_circle_outline_rounded
                          : (_selectedType == TransactionType.expense ? Icons.add_circle_outline_rounded : Icons.add_card_outlined),
                      size: 22
                    ),
                    label: Text(
                      isEditing
                          ? 'Update Expense'
                          : (_selectedType == TransactionType.expense ? 'Save Expense' : 'Save Income'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == TransactionType.expense ? primarySheetColor : Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    onPressed: () async {
                      // ... (既存の保存ロジックは変更なし)
                        final String amountStr = _expenseAmountController.text.trim();
                        final String descriptionStr = _expenseDescriptionController.text.trim();
                        final double? enteredAmount = double.tryParse(amountStr);
                        
                        if (enteredAmount == null || enteredAmount <= 0) {
                          setSheetState(() => localErrorText = "Please enter a valid positive amount."); return;
                        }
                        bool categoryIsValid = currentCategories.any((cat) => cat.itemName == _category);
                        if (_category.isEmpty || !categoryIsValid) {
                          setState(() { _category = defaultCategory; });
                          setSheetState(() => localErrorText = "Please select a valid category.");
                          return;
                        }
                        setSheetState(() => localErrorText = "");

                        try {
                          String docId = isEditing ? _editedId : const Uuid().v4();
                          int expenseDay;

                          if (isEditing && _editingDateNum.isNotEmpty) {
                             
                              expenseDay = int.tryParse(_editingDateNum) ?? DateTime.now().day;
                          } else {
                              expenseDay = DateTime.now().day;
                          }
                          // 親ウィジェットの _year, _month, _formattedDate, userId はアクセス可能と仮定します。
                          // これらが未定義の場合は、適切に渡すか、親ウィジェットのスコープで解決する必要があります。
                          // 例: DateTime(_year, _month, expenseDay);
                          // await FirebaseFirestore.instance.collection("expenses").doc(userId.uid)...

                          // ここではダミーの _year, _month, _formattedDate, userId を使います。
                          // 実際には親ウィジェットから取得してください。
                          int _year = DateTime.now().year;
                          int _month = DateTime.now().month;
                          String _formattedDate = "${_year}-${_month.toString().padLeft(2, '0')}";
                          // String userIdUid = FirebaseAuth.instance.currentUser?.uid ?? "default_user_id";


                          try {
                              DateTime(_year, _month, expenseDay);
                          } catch (e) {
                              setSheetState(() => localErrorText = "Invalid day for selected month/year.");
                              return;
                          }

                          Map<String, dynamic> dataToSave = {
                            "type": _selectedType == TransactionType.expense ? "expense" : "income",
                            "category": _category,
                            "amount": _selectedType == TransactionType.expense? -enteredAmount : enteredAmount,
                            "description": descriptionStr,
                            "date": expenseDay,
                            "monthYear": _formattedDate, // 親のStateから取得することを想定
                            "expenseId": docId,
                            "timestamp": FieldValue.serverTimestamp(),
                          };
                          
                          // Firebaseへの保存処理 (userId.uid と _formattedDate を適切に設定してください)
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) {
                            setSheetState(() => localErrorText = "User not logged in.");
                            return;
                          }

                          await FirebaseFirestore.instance
                              .collection("expenses")
                              .doc(currentUser.uid) // userId.uid の代わりに currentUser.uid を使用
                              .collection(_formattedDate) // 親のStateから取得することを想定
                              .doc(docId)
                              .set(dataToSave, SetOptions(merge: isEditing));


                          Navigator.pop(modalContext);
                          // fetchData(_formattedDate); // 親ウィジェットのデータ更新メソッドを呼び出す

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${_selectedType == TransactionType.expense ? "Expense" : "Income"} ${isEditing ? "updated" : "saved"} successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating
                            ),
                          );

                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save ${_selectedType == TransactionType.expense ? "expense" : "income"}: $e'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating
                              ),
                            );
                          }
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

// ... (他のコードはそのまま)
}