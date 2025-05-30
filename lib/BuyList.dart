import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:moneymanager/themeColor.dart'; // Assuming this file exists and defines 'theme'
import 'package:moneymanager/uid/uid.dart'; // Assuming this file exists and defines 'userId'
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // For date formatting

class BuyList extends StatefulWidget {
  const BuyList({super.key});

  @override
  _BuyListState createState() => _BuyListState();
}

class _BuyListState extends State<BuyList> {
  final DraggableScrollableController draggableController = DraggableScrollableController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  @override
  void dispose() {
    draggableController.dispose();
    itemNameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _showAddItemSheet() {

    showModalBottomSheet(
      enableDrag: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent, // Make sheet background transparent
      builder: (context) {
        return DraggableScrollableSheet(
          controller: draggableController,
          initialChildSize: 0.5, // Adjusted for better initial view
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          
          builder: (context, scrollController) {
            return StatefulBuilder( // Needed to update sheet content if necessary
              builder: (context, StateSetter setStateModal) {
                return Container(
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Adjust for keyboard
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 3,
                        blurRadius: 10,
                        offset: Offset(0, -3), // Shadow for the top edge
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center( // Handle for dragging
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Add New Item',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22, // Slightly reduced for balance
                          fontWeight: FontWeight.bold,
                          color: theme.shiokuriBlue, // Use theme color
                        ),
                      ),
                      SizedBox(height: 25),
                      TextField(
                        controller: itemNameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g., Coffee Beans',
                          prefixIcon: Icon(Icons.shopping_basket_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.shiokuriBlue, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onTap: () {
                          draggableController.animateTo(
                            0.9,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Price (RM)',
                          hintText: 'e.g., 25.50',
                          prefixIcon: Icon(Icons.attach_money),
                           border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.shiokuriBlue, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onTap: () {
                          draggableController.animateTo(
                            0.9,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                      SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Add Item', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.shiokuriBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () async {
                          if (itemNameController.text.isNotEmpty &&
                              priceController.text.isNotEmpty) {
                            Uuid uuid = Uuid();
                            String itemId = uuid.v4();
                            // Try parsing price, default to 0.0 if invalid
                            double price = double.tryParse(priceController.text) ?? 0.0;

                            Navigator.pop(context); // Close modal before async operation

                            try {
                              await FirebaseFirestore.instance
                                  .collection('buyList')
                                  .doc(userId.uid)
                                  .collection('items')
                                  .doc(itemId)
                                  .set({
                                'itemName': itemNameController.text,
                                'price': price.toString(), // Store as string or number based on preference
                                'createdAt': FieldValue.serverTimestamp(), // Optional: for sorting
                              });
                              itemNameController.clear();
                              priceController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Item added successfully!')),
                              );
                            } catch (error) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to add item: $error')),
                              );
                              print('Failed to add item: $error');
                            }
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please fill in all fields.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor, // Fallback background color
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        backgroundColor: theme.shiokuriBlue,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text("Add Item", style: TextStyle(color: Colors.white)),
        elevation: 4.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow for a flatter look initially
        flexibleSpace: Container( // Use flexibleSpace for gradient or custom background
          decoration: BoxDecoration(
            color: theme.shiokuriBlue,
            borderRadius: BorderRadius.only(
                 bottomRight: Radius.circular(30), // Adjusted radius
                 bottomLeft: Radius.circular(30)
            )
          ),
        ),
        title: Text(
          "Shopping List",
          style: theme.normal.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('buyList')
            .doc(userId.uid)
            .collection('items')
            .orderBy('createdAt', descending: true) // Optional: Sort by creation time
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.shiokuriBlue));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Your shopping list is empty!",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap '+' to add new items.",
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text("Something went wrong: ${snapshot.error}", style: TextStyle(color: Colors.red)));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.only(top:10, bottom: 80), // Padding for FAB
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final itemName = data['itemName'] as String? ?? 'Unnamed Item';
              final priceString = data['price'] as String? ?? '0';
              final price = double.tryParse(priceString) ?? 0.0;

              return Dismissible(
                key: Key(doc.id),
                background: _buildSwipeActionLeft(), // Right swipe (Add to Expenses)
                secondaryBackground: _buildSwipeActionRight(), // Left swipe (Delete)
                onDismissed: (direction) async {
                  if (direction == DismissDirection.startToEnd) { // Swiped Right
                    await addToExpense(itemName, price, doc.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$itemName added to expenses & removed from list.')),
                    );
                  } else if (direction == DismissDirection.endToStart) { // Swiped Left
                    await FirebaseFirestore.instance
                        .collection('buyList')
                        .doc(userId.uid)
                        .collection('items')
                        .doc(doc.id)
                        .delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$itemName removed from list.')),
                    );
                  }
                },
                child: Card(
                  elevation: 3,
                  margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: theme.shiokuriBlue.withOpacity(0.1),
                      child: Icon(Icons.local_mall_outlined, color: theme.shiokuriBlue),
                    ),
                    title: Text(
                      itemName,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                    ),
                    subtitle: Text(
                      'Price: RM ${price.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    trailing: Icon(Icons.drag_handle, color: Colors.grey[300]), // Hint for swipe
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
      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.add_task_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text(
            'Add to Expenses',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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
      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      alignment: Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Delete Item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 10),
          Icon(Icons.delete_sweep_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Future<void> addToExpense(String name, double itemPrice, String buyListItemId) async {
    DateTime now = DateTime.now();
    // Using intl for more robust date formatting if needed, but basic works fine too.
    String formattedDate = DateFormat('yyyy-MM').format(now); // Ensures MM format

    // Create a unique ID for the expense item
    Uuid uuid = Uuid();
    String expenseId = uuid.v4();

    try {
      // Add to expenses collection
      await FirebaseFirestore.instance
          .collection("expenses")
          .doc(userId.uid)
          .collection(formattedDate)
          .doc(expenseId) // Use a unique ID for the new expense document
          .set({
        "category": 'Shopping', // Or 'Others' if you prefer
        "amount": itemPrice,
        "description": name,
        "date": now.day, // Storing day of the month
        "fullDate": Timestamp.fromDate(now), // Storing full timestamp for sorting/querying
        "sourceBuyListId": buyListItemId, // Optional: link back to the buy list item
      });

      // Then delete from buyList (this is now handled in onDismissed for clarity)
      // await FirebaseFirestore.instance
      //     .collection('buyList')
      //     .doc(userId.uid)
      //     .collection('items')
      //     .doc(buyListItemId)
      //     .delete();

      print('Item added to expenses and removed from buy list.');
    } catch (error) {
      print('Failed to process item to expense: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error moving item to expenses: $error')),
      );
      // Optionally, re-add to buy list or handle error appropriately
    }
  }
}
