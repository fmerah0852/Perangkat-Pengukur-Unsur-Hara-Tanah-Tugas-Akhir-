// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ble_provider.dart';
import 'pages/dashboard_page.dart';
import 'pages/history_page.dart';
import 'auth_provider.dart'; // Tambahkan ini
import 'pages/login_page.dart'; // Tambahkan ini

void main() {
  runApp(
    MultiProvider( // Gunakan MultiProvider karena sekarang ada 2 provider
      providers: [
        ChangeNotifierProvider(create: (_) => BleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()), // Provider Baru
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        primaryColor: Colors.deepPurple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}



// Widget ini mengatur Bottom Navigation Bar
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0; // Halaman 0 adalah halaman pertama

  static const List<Widget> _pages = <Widget>[
    DashboardPage(), // Halaman 1 (Grid)
    HistoryPage(),   // Halaman 2 (Riwayat & Sync)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History & Sync',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}
