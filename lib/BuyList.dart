
import 'package:flutter/material.dart';
import 'package:moneymanager/themeColor.dart';

class BuyList extends StatefulWidget {
  @override
  _BuyListState createState() => _BuyListState();
}


class _BuyListState extends State<BuyList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(context: context, builder: (context){
            return Container(
              height: 300,
              child: Column(
                children: [
                  Text('Add New Item'),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Price',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Add your logic to save the item
                      Navigator.pop(context);
                    },
                    child: Text('Save'),
                  ),
                ],
              ),
            );
          });
        },
        child: Icon(Icons.add),
        backgroundColor: theme.shiokuriBlue,
      ),
      appBar: AppBar(
        title: Text('Buy List',
        style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            
          ),),
        centerTitle: true,
        backgroundColor: theme.shiokuriBlue,
      ),
      body: Center(
      )
    );
  }
}