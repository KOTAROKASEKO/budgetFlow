import 'package:flutter/material.dart';
import 'package:moneymanager/Transaction_Views/buyLlist/BuyList.dart';
import 'package:moneymanager/Transaction_Views/dashboard/DashBoard.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/View_DashBoard.dart';
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
    FinancialGoalPage(),
    Dashboard(),
    BuyList(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _performUpdateCheck();
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★ 修正点: 背景色をダークに
      backgroundColor: theme.apptheme_Black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          // ★ 修正点: ナビゲーションバーの背景もダークに
          color: Colors.grey.shade900,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home, "RoadMap", 0),
            _buildNavItem(Icons.monetization_on_outlined, Icons.monetization_on, "Budgeting", 1),
            _buildNavItem(Icons.list_alt_outlined, Icons.list_alt, "Shopping", 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}