import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'tabs/home_tab.dart';
import 'tabs/report_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const HomeTab(),
    const ReportIssueTab(),
    const MapTab(),
    const ProfileTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  Future<void> _showExitToast() async {
    final now = DateTime.now();
    if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: 'Press back again to exit',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } else {
      // exit app
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _selectedIndex = index);
          },
          children: _screens,
        ),
        floatingActionButton: _selectedIndex == 1
            ? FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/report');
          },
          tooltip: 'Report New Issue',
          child: const Icon(Icons.add),
        )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
