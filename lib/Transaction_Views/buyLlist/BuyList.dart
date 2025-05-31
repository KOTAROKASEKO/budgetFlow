import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive Flutter
import 'package:intl/intl.dart'; // For date formatting
import 'package:moneymanager/Transaction_Views/buyLlist/model/buy_list_item_model.dart';
import 'package:moneymanager/Transaction_Views/dashboard/database/dasboardDB.dart';
import 'package:moneymanager/themeColor.dart'; // Assuming this file exists
import 'package:moneymanager/uid/uid.dart'; // Assuming this file exists
import 'package:uuid/uuid.dart';

import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart';

class BuyList extends StatefulWidget {
  const BuyList({super.key});

  @override
  _BuyListState createState() => _BuyListState();
}

class _BuyListState extends State<BuyList> {
  final DraggableScrollableController draggableController = DraggableScrollableController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  
  late Box<BuyListItem> _buyListBox;
  double _totalPlannedExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _buyListBox = Hive.box<BuyListItem>(dashBoardDBManager.buyListItemsBoxName);
    _calculateTotalPlannedExpense();
    _buyListBox.watch().listen((event) { // Listen for changes to update total
        _calculateTotalPlannedExpense();
    });
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
    // Hive boxes are typically kept open for the app's lifetime
    // If you specifically need to close it: await _buyListBox.close();
    super.dispose();
  }

  void _showAddItemSheet() {
    // Clear fields before showing the sheet
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
                    top: 20, left: 20, right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25), topRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 3, blurRadius: 10, offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 5,
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
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: theme.shiokuriBlue, // Use theme color
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: itemNameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Item Name', hintText: 'e.g., Coffee Beans',
                          prefixIcon: const Icon(Icons.shopping_basket_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.shiokuriBlue, width: 2),
                          ),
                          filled: true, fillColor: Colors.grey[50],
                        ),
                        onTap: () {
                          draggableController.animateTo(
                            0.9, duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Price (RM)', hintText: 'e.g., 25.50',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.shiokuriBlue, width: 2),
                          ),
                          filled: true, fillColor: Colors.grey[50],
                        ),
                        onTap: () {
                          draggableController.animateTo(
                            0.9, duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add Item', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.shiokuriBlue,
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
                            final double price = double.tryParse(priceController.text) ?? 0.0;
                            final String itemName = itemNameController.text;

                            final newItem = BuyListItem(
                              id: itemId,
                              itemName: itemName,
                              price: price,
                              createdAt: DateTime.now(),
                            );

                            await _buyListBox.put(itemId, newItem); // Save to Hive

                            itemNameController.clear();
                            priceController.clear();
                            Navigator.pop(context); // Close modal

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Item added successfully!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in all fields.')),
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
    String formattedDate = DateFormat('yyyy-MM').format(now); // Ensures MM format (e.g., "2023-11")
    Uuid uuid = const Uuid();
    String expenseId = uuid.v4();

    try {
      // 1. Add to Firebase expenses collection
      await FirebaseFirestore.instance
          .collection("expenses")
          .doc(userId.uid) // Make sure userId.uid is available and correct
          .collection(formattedDate)
          .doc(expenseId)
          .set({
        "category": 'Shopping', // Or 'Others'
        "amount": item.price,
        "description": item.itemName,
        "date": now.day, // Storing day of the month
        "monthYear": formattedDate, // Storing YYYY-MM for easier querying if needed
        "expenseId": expenseId, // Storing the generated expenseId
        "fullDate": Timestamp.fromDate(now), // Storing full timestamp
        "timestamp": FieldValue.serverTimestamp(), // Firestore server timestamp
        "type": "expense", // To distinguish from income if this collection is shared
        "sourceBuyListId": item.id, 
      });

      // 2. Add to Hive expenses cache (monthlyExpensesCache)
      // This logic should mirror how DashBoard.dart adds expenses to its cache
      final expenseCacheBox = Hive.box<List<dynamic>>(dashBoardDBManager.expenseCacheBoxName); // Corrected box name
      final cacheKey = '${userId.uid}_$formattedDate';
      
      List<dynamic> cachedMonthExpensesDynamic = expenseCacheBox.get(cacheKey) ?? [];
      // Ensure all elements are indeed expenseModel or handle conversion/casting carefully
      List<expenseModel> cachedMonthExpenses = cachedMonthExpensesDynamic.cast<expenseModel>().toList();


      final newExpense = expenseModel(
        id: expenseId,
        amount: -item.price, // Expenses are typically negative
        date: now.day,
        description: item.itemName,
        category: 'Shopping',
        type: 'expense',
        timestamp: now, // Local timestamp for cache
        monthYear: formattedDate,
      );
      cachedMonthExpenses.add(newExpense);
      // Optional: Sort if your dashboard relies on a specific order from cache
      cachedMonthExpenses.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
      await expenseCacheBox.put(cacheKey, cachedMonthExpenses);
      
      print('Item added to Firebase expenses and Hive cache.');

      // 3. Delete from BuyList Hive box (done in onDismissed after this call)
      // This will be handled by the onDismissed callback after this function completes successfully.

    } catch (error) {
      print('Failed to process item to expense: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving item to expenses: $error')),
        );
      }
      // Optionally, re-add to buy list or handle error appropriately
      // Since we are optimistic, if it fails, the item might remain in the buy list
      // or you might need a mechanism to revert/retry.
      rethrow; // Rethrow to prevent deletion from buy list if this fails
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        backgroundColor: theme.shiokuriBlue,
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
            color: theme.shiokuriBlue,
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
              style: theme.normal.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              "Total Plan: RM ${_totalPlannedExpense.toStringAsFixed(2)}",
              style: theme.normal.copyWith(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<Box<BuyListItem>>(
        valueListenable: _buyListBox.listenable(),
        builder: (context, box, _) {
          final items = box.values.toList().cast<BuyListItem>();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_checkout_rounded, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text("Your shopping list is empty!", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 10),
                  Text("Tap '+' to add new items.", style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80), // Padding for FAB
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Dismissible(
                key: Key(item.id), // Use item's unique ID from Hive object
                background: _buildSwipeActionLeft(), // Right swipe (Add to Expenses)
                secondaryBackground: _buildSwipeActionRight(), // Left swipe (Delete)
                onDismissed: (direction) async {
                  if (direction == DismissDirection.startToEnd) { // Swiped Right (Add to Expenses)
                    try {
                        await addToExpense(context, item); // Pass context here
                        await _buyListBox.delete(item.key); // Delete from Hive after successful Firebase/cache add
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${item.itemName} added to expenses')),
                            );
                         }
                    } catch (e) {
                        // Error already handled in addToExpense, item remains in list
                        print("Dismissal cancelled due to error in addToExpense: $e");
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar( // Show specific error
                                SnackBar(content: Text('Failed to move to expenses. Item restored.')),
                            );
                         }
                         // To "restore" the item visually if optimistic UI was used, you might need to re-fetch or re-add.
                         // However, since we await, if addToExpense fails and rethrows, delete won't happen.
                         // If it doesn't rethrow, then this part is tricky. Best is for addToExpense to be robust.
                    }
                  } else if (direction == DismissDirection.endToStart) { // Swiped Left (Delete)
                    await _buyListBox.delete(item.key); // Delete from Hive
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${item.itemName} removed from list.')),
                        );
                     }
                  }
                   _calculateTotalPlannedExpense(); // Recalculate total after any dismissal
                },
                child: Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: theme.shiokuriBlue.withOpacity(0.1),
                      child: Icon(Icons.local_mall_outlined, color: theme.shiokuriBlue),
                    ),
                    title: Text(
                      item.itemName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                    ),
                    subtitle: Text(
                      'Price: RM ${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    trailing: Icon(Icons.drag_handle, color: Colors.grey[300]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSwipeActionLeft() { // For Right Swipe: Add to expenses
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
          Text('Add to Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSwipeActionRight() { // For Left Swipe: Delete
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
          Text('Delete Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(width: 10),
          Icon(Icons.delete_sweep_rounded, color: Colors.white),
        ],
      ),
    );
  }
}