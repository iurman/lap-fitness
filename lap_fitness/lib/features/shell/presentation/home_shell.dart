// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../feed/presentation/feed_page.dart';
import '../../meals/presentation/meal_tracking_page.dart';
import '../../notes/presentation/calendar_page.dart';
import '../../notes/presentation/notes_page.dart';
import '../../workout/presentation/workout_tracker_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2;

  static final List<Map<String, dynamic>> _sections = [
    {'name': 'Feed', 'icon': Icons.rss_feed, 'page': FeedPage()},
    {
      'name': 'Notes',
      'icon': Icons.note,
      'page': NotesPage(selectedDate: DateTime.now())
    },
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
        backgroundColor: AppColors.brand,
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
                  onPressed: () => context.push(Routes.settings),
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
                  Center(
                    child: SizedBox(
                      height: 80,
                      child: Image.asset('assets/images/lap2.png'),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Welcome to the App!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.push(Routes.editProfile),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'New or want to change user info?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              "Press Here!",
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.brand,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Ready to Workout?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.push(Routes.workout),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Press here!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              "Let's kill it today",
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Water Intake',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.push(Routes.water),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'How much did you drink?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Tap Here',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.brand,
                              ),
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
                  color: AppColors.brand,
                ),
                label: section['name'],
                backgroundColor: Colors.white,
              ),
            )
            .toList(),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.brand,
      ),
    );
  }
}
