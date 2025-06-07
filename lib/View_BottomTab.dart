import 'package:flutter/material.dart';
import 'package:moneymanager/Transaction_Views/buyLlist/BuyList.dart';
import 'package:moneymanager/Transaction_Views/dashboard/DashBoard.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/View_AIRoadMap.dart';
import 'package:moneymanager/showUpdate.dart';
import 'package:moneymanager/themeColor.dart';

class BottomTab extends StatefulWidget {
  const BottomTab({super.key});

  @override
  _BottomTabState createState() => _BottomTabState();
}

class _BottomTabState extends State<BottomTab> {

  final ShowUpdate _updateChecker = ShowUpdate();
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    Dashboard(),
    BuyList(),
    FinancialGoalPage(),
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _performUpdateCheck();
  }

  void _performUpdateCheck() {
    _updateChecker.checkUpdate(context, (currentVersion, newVersion) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
              title: const Text("Update Available",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Text(
                  "A newer version ($newVersion) is available.\nCurrent Version: $currentVersion"),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10)),
                  child: const Text("Later"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.apptheme_Black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0))),
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child:Scaffold(
      backgroundColor: theme.backgroundColor,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.monetization_on),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'List',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.smart_toy),
                label: 'List',
              ),
            ],
          ),
        ),
      ),
    ),
  );}
}
