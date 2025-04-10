import 'package:flutter/material.dart';
import 'package:moneymanager/BuyList.dart';
import 'package:moneymanager/DashBoard.dart';

class BottomTab extends StatefulWidget {
  const BottomTab({Key? key}) : super(key: key);

  @override
  _BottomTabState createState() => _BottomTabState();
}
class _BottomTabState extends State<BottomTab> {

  int _selectedIndex = 0;

  List<Widget> _pages = [
    Dashboard(),
    BuyList(),
  ];

  void changeIndex() {
    setState(() {
      _selectedIndex = _selectedIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],
          
          Positioned(
            right:100,
            bottom: 11,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child:Container(
              width: 240,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow:[BoxShadow(
                  color: const Color.fromARGB(255, 209, 209, 209),
                  blurRadius: 3,
                  spreadRadius: 3,
                  offset: Offset(0, 2),
                )],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                      
                    child:Image.asset(
                      'assets/home.png',
                      width:_selectedIndex == 0? 40:20,
                      height: 40,
                      
                      ),

                    onTap: () {
                      _selectedIndex = 0;
                      changeIndex();
                    },
                    ),
                  GestureDetector(
                    onTap: () {
                      _selectedIndex = 1;
                      changeIndex();
                    },
                    child:Icon(
                      size: _selectedIndex == 1? 40:20,
                      Icons.list, color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    )
                ],
              ),
            ))
          
          )
        ],
      )
    );
  }
}
