// ignore_for_file: prefer_const_constructors

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'feed_page.dart';
import 'note_page.dart';
import 'meal_tracking_page.dart';
import 'calendar_page.dart';
import 'home.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser!;
  int _selectedIndex = 2;

  static final List<Map<String, dynamic>> _sections = [
    {'name': 'Feed', 'icon': Icons.rss_feed, 'page': FeedPage()},
    {'name': 'Notes', 'icon': Icons.note, 'page': NotePage()},
    {'name': 'Home', 'icon': Icons.home, 'page': Home()},
    {
      'name': 'Meal Tracking',
      'icon': Icons.restaurant_menu,
      'page': MealTrackingPage()
    },
    {'name': 'Calendar', 'icon': Icons.calendar_today, 'page': CalendarPage()},
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _sections[_selectedIndex]
            ['page'], // Use the selected page based on the current index
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: _sections
            .map((section) => BottomNavigationBarItem(
                  icon: Icon(section['icon']),
                  label: section['name'],
                ))
            .toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
