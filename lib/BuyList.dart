import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:uuid/uuid.dart';

class BuyList extends StatefulWidget {
  @override
  _BuyListState createState() => _BuyListState();
}

class _BuyListState extends State<BuyList> {
  final DraggableScrollableController draggableController =
      DraggableScrollableController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              enableDrag: true,
              isScrollControlled: true,
              context: context,
              builder: (context) {
                return DraggableScrollableSheet(
                  controller: draggableController,
                  initialChildSize: 0.4,
                  minChildSize: 0.4,
                  maxChildSize: 0.95, // allow it to expand more
                  expand: false,
                  builder: (context, scrollController) {
                    return StatefulBuilder(
                      builder: (context, StateSetter setState) {
                        return Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListView(
                            controller: scrollController,
                            children: [
                              Text(
                                'Add New Item',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 20),
                              TextField(
                                controller: itemNameController,
                                onTap: () {
                                  draggableController.animateTo(
                                    0.95, // maxChildSize
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                decoration: InputDecoration(
                                  labelText: 'Item Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 20),
                              TextField(
                                controller: priceController,
                                onTap: () {
                                  draggableController.animateTo(
                                    0.95,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                decoration: InputDecoration(
                                  labelText: 'Price',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 20),
                              GestureDetector(
                                onTap: () {
                                  

                                  Uuid uuid = Uuid();
                                  String itemId = uuid.v4();
                                  Navigator.pop(context);
                                  FirebaseFirestore.instance
                                      .collection('buyList')
                                      .doc(userId.uid)
                                      .collection('items')
                                      .doc(itemId)
                                      .set({
                                    'itemName': itemNameController.text,
                                    'price': priceController.text,
                                  }).then((_) {
                                    itemNameController.clear();
                                    priceController.clear();
                                    return null;
                                  })
                                  .catchError((error) =>
                                    // ignore: invalid_return_type_for_catch_error
                                    print('Failed to add item: $error'));
                                },
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: theme.shiokuriBlue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Add Item',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
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
          },
          child: Icon(Icons.add),
          backgroundColor: theme.shiokuriBlue,
        ),
        appBar: AppBar(
          title: Text(
            'Buy List',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: theme.shiokuriBlue,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('buyList')
              .doc(userId.uid)
              .collection('items')
              .snapshots(), // 🔥 ここを修正
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final itemName = data['itemName'] ?? 'No Item';
                final price = double.tryParse(data['price'] ?? '0') ?? 0;

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    addToExpense(doc['itemName'], double.tryParse(doc['price'])??0);

                    await FirebaseFirestore.instance
                        .collection('buyList')
                        .doc(userId.uid)
                        .collection('items')
                        .doc(doc.id)
                        .delete();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$itemName was deleted')),
                    );
                    
                  },
                  child:  Card(
                    elevation: 4, // ← ここでシャドウの強さを調整できる（1〜10くらいがオススメ）
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.shopping_cart),
                      title: Text(itemName),
                      subtitle: Text('Price: RM ${price.toStringAsFixed(2)}'),
                    ),
                  )

                );
              },
            );
          },
        ));
  }
  
  Future<void> addToExpense(String name, double itemPrice) async{
    DateTime now = DateTime.now();
    int year = now.year;
    int month = now.month;
    String formattedDate = "${year}-${month.toString().padLeft(2, '0')}";
    await FirebaseFirestore.instance
        .collection("expenses")
        .doc(userId.uid)
        .collection(formattedDate)
        .doc()
        .set({
      "category": 'others',
      "amount": itemPrice,
      "description": name,
      "date":now.day,
    });
  }
}
