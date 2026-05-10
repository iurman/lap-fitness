import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';
import 'feed_page.dart';
import 'meal_tracking_page.dart';
import 'note_page.dart';
import 'settings_page.dart';
import 'user_info.dart';
import 'water_tracker.dart';
import 'workout_tracker.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _homeTabIndex = 2;
  static const List<_HomeTab> _tabs = [
    _HomeTab(name: 'Feed', icon: Icons.rss_feed),
    _HomeTab(name: 'Notes', icon: Icons.note),
    _HomeTab(name: 'Home', icon: Icons.home),
    _HomeTab(name: 'Meal Tracking', icon: Icons.restaurant_menu),
    _HomeTab(name: 'Calendar', icon: Icons.calendar_today),
  ];

  int _selectedIndex = _homeTabIndex;

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Widget _buildTabBody(int index) {
    switch (index) {
      case 0:
        return const FeedPage();
      case 1:
        return NotesPage(selectedDate: DateTime.now());
      case 2:
        return _HomeTabBody();
      case 3:
        return const MealTrackingPage();
      case 4:
        return const CalendarPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_selectedIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: BrandAppBar(
        title: tab.name,
        automaticallyImplyLeading: false,
        actions: _selectedIndex == _homeTabIndex
            ? [
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: _buildTabBody(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.brand,
        items: _tabs
            .map(
              (t) => BottomNavigationBarItem(
                icon: Icon(t.icon, color: AppColors.brand),
                label: t.name,
                backgroundColor: Colors.white,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HomeTab {
  final String name;
  final IconData icon;
  const _HomeTab({required this.name, required this.icon});
}

class _HomeTabBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              height: 80,
              child: Image.asset('assets/images/lap2.png'),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Welcome to the App!'),
          const SizedBox(height: 16),
          _HomeCard(
            title: 'New or want to change user info?',
            actionLabel: 'Press Here!',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserInfoPage()),
            ),
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Ready to Workout?'),
          const SizedBox(height: 16),
          _HomeCard(
            title: 'Press here!',
            actionLabel: "Let's kill it today",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkoutTracker()),
            ),
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Water Intake'),
          const SizedBox(height: 16),
          _HomeCard(
            title: 'How much did you drink?',
            actionLabel: 'Tap Here',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WaterTracker()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              actionLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.brand),
            ),
          ],
        ),
      ),
    );
  }
}
