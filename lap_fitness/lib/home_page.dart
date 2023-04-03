import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feed_page.dart';
import 'note_page.dart';
import 'meal_tracking_page.dart';
import 'calendar_page.dart';
import 'home.dart';
import 'settings_page.dart';
import 'package:lap_fitness/workout_tracker.dart';

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
    {'name': 'Notes', 'icon': Icons.note, 'page': NotesPage()},
    {'name': 'Home', 'icon': Icons.home, 'page': WorkoutTrackerPage()},
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
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        title: Text(_sections[_selectedIndex]['name']),
        automaticallyImplyLeading: false, // hide back button
        actions: _selectedIndex == 2 // hide back button
            ? [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsPage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.settings),
                ),
              ]
            : null,
      ),
      body: _sections[_selectedIndex]['page'],
      bottomNavigationBar: BottomNavigationBar(
        items: _sections
            .map(
              (section) => BottomNavigationBarItem(
                icon: Icon(section['icon']),
                label: section['name'],
              ),
            )
            .toList(),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color.fromARGB(255, 138, 104, 35),
        unselectedItemColor: Color.fromARGB(255, 138, 104, 35),
      ),
    );
  }
}
