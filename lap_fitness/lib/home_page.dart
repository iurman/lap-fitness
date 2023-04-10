// ignore_for_file: prefer_const_constructors

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
import 'package:lap_fitness/loading_page.dart';

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
    {'name': 'Home', 'icon': Icons.home, 'page': WorkoutTracker()},
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        title: Text(
          _sections[_selectedIndex]['name'],
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: _selectedIndex == 2
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
                  icon: Icon(
                    Icons.settings,
                    color: Colors.white,
                  ),
                ),
              ]
            : null,
      ),
      body: _selectedIndex == 2
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calories for the day',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 138, 104, 35),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 246, 246, 246),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '1800',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 32),
                  Text(
                    'Workout of the day',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 138, 104, 35),
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutTracker(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 246, 246, 246),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upper Body Workout',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '3 sets of 10 reps',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color.fromARGB(255, 138, 104, 35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _sections[_selectedIndex]['page'],
      bottomNavigationBar: BottomNavigationBar(
        items: _sections
            .map(
              (section) => BottomNavigationBarItem(
                icon: Icon(
                  section['icon'],
                  color: Color.fromARGB(255, 138, 104, 35),
                ),
                label: section['name'],
                backgroundColor: Colors.white,
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
