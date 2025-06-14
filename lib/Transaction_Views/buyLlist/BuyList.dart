import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Import for ads
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:moneymanager/Transaction_Views/buyLlist/model/buy_list_item_model.dart';
import 'package:moneymanager/Transaction_Views/dashboard/database/dasboardDB.dart';
import 'package:moneymanager/ads/ViewModel_ads.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/security/uid.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart';

class BuyList extends StatefulWidget {
  const BuyList({super.key});

  @override
  _BuyListState createState() => _BuyListState();
}

class _BuyListState extends State<BuyList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final DraggableScrollableController draggableController =
      DraggableScrollableController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  late Box<BuyListItem> _buyListBox;
  double _totalPlannedExpense = 0.0; // For AppBar "Total Plan"

  // State variables for simulation
  double _actualTodaysBaseExpense = 0.0;
  int _actualTodaysExpenseCount = 0;
  Set<String> _selectedBuyListItemIds = {};
  double _simulatedTodaysTotalExpense = 0.0;
  double _simulatedTodaysAverageExpense = 0.0;
  String adKey = 'buyList_Ad';

  // Ad variables
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _buyListBox = Hive.box<BuyListItem>(dashBoardDBManager.buyListItemsBoxName);
    _fetchActualTodaysBaseData();
    _calculateTotalPlannedExpense(); // For AppBar

    _buyListBox.watch().listen((event) {
      _calculateTotalPlannedExpense(); // Update AppBar total

      bool itemRemovedFromSelection = false;
      if (event.deleted &&
          _selectedBuyListItemIds.contains(event.key as String)) {
        _selectedBuyListItemIds.remove(event.key as String);
        itemRemovedFromSelection = true;
      }

      if (itemRemovedFromSelection || !event.deleted) {
        _recalculateSimulatedExpenses();
      }
      if (mounted) {
        setState(() {}); // Refresh list
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdViewModel>(context, listen: false).loadAd(adKey);
    });
  }

  Future<void> _fetchActualTodaysBaseData() async {
    DateTime now = DateTime.now();
    String formattedMonthYear = DateFormat('yyyy-MM').format(now);
    int currentDay = now.day;
    double sumOfTodaysExpenses = 0.0;
    int countOfTodaysExpenses = 0;

    try {
      final expenseCacheBox =
          Hive.box<List<dynamic>>(dashBoardDBManager.expenseCacheBoxName);
      final cacheKey = '${userId.uid}_$formattedMonthYear';
      List<dynamic>? cachedMonthData = expenseCacheBox.get(cacheKey);

      if (cachedMonthData != null) {
        List<expenseModel> monthTransactions =
            cachedMonthData.cast<expenseModel>().toList();
        for (var expense in monthTransactions) {
          if (expense.date == currentDay && expense.type == 'expense') {
            sumOfTodaysExpenses += expense.amount.abs();
            countOfTodaysExpenses++;
          }
        }
      }
    } catch (e) {
      print("Error fetching today's base expense data: $e");
    }

    if (mounted) {
      setState(() {
        _actualTodaysBaseExpense = sumOfTodaysExpenses;
        _actualTodaysExpenseCount = countOfTodaysExpenses;
        _recalculateSimulatedExpenses();
      });
    }
  }

  void _recalculateSimulatedExpenses() {
    double selectedItemsPriceSum = 0.0;
    for (String itemId in _selectedBuyListItemIds) {
      final item = _buyListBox.get(itemId);
      if (item != null) {
        selectedItemsPriceSum += item.price;
      }
    }

    _simulatedTodaysTotalExpense =
        _actualTodaysBaseExpense + selectedItemsPriceSum;

    int totalSimulatedItemsCount =
        _actualTodaysExpenseCount + _selectedBuyListItemIds.length;
    if (totalSimulatedItemsCount > 0) {
      _simulatedTodaysAverageExpense =
          _simulatedTodaysTotalExpense / totalSimulatedItemsCount;
    } else {
      _simulatedTodaysAverageExpense = 0.0;
    }
  }

  void _toggleBuyListItemSelection(String itemId) {
    if (mounted) {
      setState(() {
        if (_selectedBuyListItemIds.contains(itemId)) {
          _selectedBuyListItemIds.remove(itemId);
        } else {
          _selectedBuyListItemIds.add(itemId);
        }
        _recalculateSimulatedExpenses();
      });
    }
  }

  void _calculateTotalPlannedExpense() {
    double total = 0.0;
    for (var item in _buyListBox.values) {
      total += item.price;
    }
    if (mounted) {
      setState(() {
        _totalPlannedExpense = total;
      });
    }
  }

  @override
  void dispose() {
    draggableController.dispose();
    itemNameController.dispose();
    priceController.dispose();
    _bannerAd?.dispose(); // Dispose the banner ad
    super.dispose();
  }

  void _showAddItemSheet() {
    itemNameController.clear();
    priceController.clear();
    showModalBottomSheet(
      enableDrag: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          controller: draggableController,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, StateSetter setStateModal) {
                return Container(
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white, // Sheet background
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 3,
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add New Item',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.apptheme_Black,
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: itemNameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g., Coffee Beans',
                          prefixIcon:
                              const Icon(Icons.shopping_basket_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.apptheme_Black, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onTap: () {
                          draggableController.animateTo(
                            0.9,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: priceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Price (RM)',
                          hintText: 'e.g., 25.50',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.apptheme_Black, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onTap: () {
                          draggableController.animateTo(
                            0.9,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add Item',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.apptheme_Black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () async {
                          if (itemNameController.text.isNotEmpty &&
                              priceController.text.isNotEmpty) {
                            final String itemId = const Uuid().v4();
                            final double price =
                                double.tryParse(priceController.text) ?? 0.0;
                            final String itemName = itemNameController.text;

                            final newItem = BuyListItem(
                              id: itemId,
                              itemName: itemName,
                              price: price,
                              createdAt: DateTime.now(),
                            );

                            await _buyListBox.put(itemId, newItem);

                            itemNameController.clear();
                            priceController.clear();
                            Navigator.pop(context); // Close modal

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Item added successfully!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please fill in all fields.')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> addToExpense(BuildContext context, BuyListItem item) async {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM').format(now);
    Uuid uuid = const Uuid();
    String expenseId = uuid.v4();

    try {
      await FirebaseFirestore.instance
          .collection("expenses")
          .doc(userId.uid)
          .collection(formattedDate)
          .doc(expenseId)
          .set({
        "category": 'Shopping',
        "amount": item.price,
        "description": item.itemName,
        "date": now.day,
        "monthYear": formattedDate,
        "expenseId": expenseId,
        "fullDate": Timestamp.fromDate(now),
        "timestamp": FieldValue.serverTimestamp(),
        "type": "expense",
        "sourceBuyListId": item.id,
      });

      final expenseCacheBox =
          Hive.box<List<dynamic>>(dashBoardDBManager.expenseCacheBoxName);
      final cacheKey = '${userId.uid}_$formattedDate';

      List<dynamic> cachedMonthExpensesDynamic =
          expenseCacheBox.get(cacheKey) ?? [];
      List<expenseModel> cachedMonthExpenses =
          cachedMonthExpensesDynamic.cast<expenseModel>().toList();

      final newExpense = expenseModel(
        id: expenseId,
        amount: -item.price,
        date: now.day,
        description: item.itemName,
        category: 'Shopping',
        type: 'expense',
        timestamp: now,
        monthYear: formattedDate,
      );
      cachedMonthExpenses.add(newExpense);
      cachedMonthExpenses.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
      await expenseCacheBox.put(cacheKey, cachedMonthExpenses);

      print('Item added to Firebase expenses and Hive cache.');
    } catch (error) {
      print('Failed to process item to expense: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving item to expenses: $error')),
        );
      }
      rethrow;
    }
  }

  Widget _buildTodaysSimulatedExpenseCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(15, 8, 15, 8), // Adjusted margin
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white, // Card background color
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Simulated Total",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "RM ${_simulatedTodaysTotalExpense.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.apptheme_Black,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.calculate_outlined,
                    color: theme.apptheme_Black, size: 28),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Simulated Avg. Per Item",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  "RM ${_simulatedTodaysAverageExpense.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        backgroundColor: theme.apptheme_Black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Item", style: TextStyle(color: Colors.white)),
        elevation: 4.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: theme.apptheme_Black,
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(30),
              bottomLeft: Radius.circular(30),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Shopping List",
              style: theme.normal
                  .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              "Total Plan: RM ${_totalPlannedExpense.toStringAsFixed(2)}",
              style: theme.normal.copyWith(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ** NEW BANNER AD LOCATION **
          _buildAd(Provider.of<AdViewModel>(context),adKey),

          _buildTodaysSimulatedExpenseCard(),
          Expanded(
            // List takes remaining space
            child: ValueListenableBuilder<Box<BuyListItem>>(
              valueListenable: _buyListBox.listenable(),
              builder: (context, box, _) {
                final items = box.values.toList().cast<BuyListItem>();
                items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_checkout_rounded,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 20),
                        Text("Your shopping list is empty!",
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600])),
                        const SizedBox(height: 10),
                        Text("Tap '+' to add new items.",
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 2,
                      bottom: 80), // Adjusted bottom padding
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final bool isSelected =
                        _selectedBuyListItemIds.contains(item.id);

                    return Dismissible(
                      key: Key(item.id),
                      background: _buildSwipeActionLeft(),
                      secondaryBackground: _buildSwipeActionRight(),
                      onDismissed: (direction) async {
                        String dismissedItemId = item.id;
                        if (direction == DismissDirection.startToEnd) {
                          try {
                            await addToExpense(context, item);
                            await _buyListBox.delete(item.key);

                            if (mounted) {
                              setState(() {
                                _selectedBuyListItemIds
                                    .remove(dismissedItemId);
                              });
                            }
                            await _fetchActualTodaysBaseData();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${item.itemName} added to expenses')),
                              );
                            }
                          } catch (e) {
                            print(
                                "Dismissal cancelled due to error in addToExpense: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Failed to move to expenses. Item restored.')),
                              );
                              setState(() {});
                            }
                          }
                        } else if (direction == DismissDirection.endToStart) {
                          await _buyListBox.delete(item.key);
                          if (mounted) {
                            setState(() {
                              bool wasSelected = _selectedBuyListItemIds
                                  .remove(dismissedItemId);
                              if (wasSelected) {
                                _recalculateSimulatedExpenses();
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '${item.itemName} removed from list.')),
                            );
                          }
                        }
                      },
                      child: Card(
                        elevation: isSelected ? 4 : 2.5,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        color: isSelected
                            ? Colors.blueGrey.withOpacity(0.9)
                            : Colors.white,
                        child: ListTile(
                          onTap: () {
                            if (_selectedBuyListItemIds.isNotEmpty) {
                              _toggleBuyListItemSelection(item.id);
                            }
                          },
                          onLongPress: () {
                            _toggleBuyListItemSelection(item.id);
                          },
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.green.withOpacity(0.8)
                                : theme.apptheme_Black.withOpacity(0.1),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.local_mall_outlined,
                              color: isSelected
                                  ? Colors.white
                                  : theme.apptheme_Black,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            item.itemName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.5,
                              color: isSelected
                                  ? theme.apptheme_Black
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Price: RM ${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: isSelected
                                    ? theme.apptheme_Black.withOpacity(0.8)
                                    : Colors.black54,
                                fontSize: 14),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.done_all_rounded,
                                  color: Colors.green, size: 22)
                              : Icon(Icons.drag_handle_rounded,
                                  color: Colors.grey[350], size: 22),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeActionLeft() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.add_task_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text('Add to Expenses',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSwipeActionRight() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Delete Item',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(width: 10),
          Icon(Icons.delete_sweep_rounded, color: Colors.white),
        ],
      ),
    );
  }
  
  Widget _buildAd(AdViewModel adViewModel, String adId) {
  // 1. isAdLoaded(adId) を使って、特定の広告のロード状態を確認します。
  if (adViewModel.isAdLoaded(adId)) {
    // 2. getAd(adId) を使って、特定の広告オブジェクトを取得します。
    final bannerAd = adViewModel.getAd(adId);

    // 広告がnullでないことを確認してから表示します。
    if (bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        child: AdWidget(ad: bannerAd),
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
      );
    } else {
      // 予期せず広告がnullだった場合の表示
      return Container(
        height: 50.0,
        alignment: Alignment.center,
        child: Text('Ad data not found.'),
      );
    }
  } else {
    // ロード中、またはロードに失敗した場合の表示
    return Container(
      height: 50.0, // バナー広告と同じ高さ
      alignment: Alignment.center,
      child: Text('Ad is loading...'),
    );
  }
}
}