import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/services.dart';
import 'package:project_track_your_finance/screens/add_transaction_screen.dart';
import 'home.dart'; // TransactionsScreen
import 'statistics_screen.dart';
import 'wallet_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const TransactionsScreen(),
    const StatisticsScreen(),
    const WalletPage(),
    const SettingsScreen(),
  ];

  final List<IconData> _iconList = [
    Icons.home_outlined,
    Icons.pie_chart_outline,
    Icons.account_balance_wallet_outlined,
    Icons.settings_outlined,
  ];

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final bottomBarColor = isDarkTheme ? Colors.black : Colors.white;
    final iconColor = isDarkTheme ? Colors.white : Colors.black;
    final activeColor = isDarkTheme ? Colors.blueAccent : Colors.blue;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bottomBarColor,
        systemNavigationBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FloatingActionButton(
            backgroundColor: activeColor,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddTransactionScreen()),
              );
            },
            elevation: 8.0,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: AnimatedBottomNavigationBar.builder(
          itemCount: _iconList.length,
          tabBuilder: (int index, bool isActive) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _iconList[index],
                  size: 26,
                  color: isActive ? activeColor : iconColor.withOpacity(0.6),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  width: isActive ? 24 : 0,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            );
          },
          activeIndex: _selectedIndex,
          notchSmoothness: NotchSmoothness.verySmoothEdge,
          gapLocation: GapLocation.center,
          onTap: _onTabSelected,
          elevation: 16.0,
          height: 70,
          backgroundColor: bottomBarColor,
          shadow: const BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ),
      ),
    );
  }
}
