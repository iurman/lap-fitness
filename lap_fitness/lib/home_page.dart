import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/animated_tap_card.dart';
import 'core/widgets/brand_app_bar.dart';
import 'feed_page.dart';
import 'meal_tracking_page.dart';
import 'note_page.dart';
import 'settings_page.dart';
import 'user_info.dart';
import 'water_tracker.dart';
import 'workout_tracker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _homeTabIndex = 2;
  static const List<_HomeTab> _tabs = <_HomeTab>[
    _HomeTab(name: 'Feed', icon: Icons.rss_feed_rounded),
    _HomeTab(name: 'Notes', icon: Icons.sticky_note_2_outlined),
    _HomeTab(name: 'Home', icon: Icons.home_rounded),
    _HomeTab(name: 'Meals', icon: Icons.restaurant_menu_rounded),
    _HomeTab(name: 'Calendar', icon: Icons.calendar_today_rounded),
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
        return const _HomeTabBody();
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
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _buildTabBody(_selectedIndex),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.brand.withValues(alpha: 0.12),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon, color: Colors.grey[600]),
                selectedIcon: Icon(t.icon, color: AppColors.brand),
                label: t.name,
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
  const _HomeTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Hero(
            tag: 'lap-logo',
            child: SizedBox(
              height: 96,
              child: Image.asset('assets/images/lap2.png'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Welcome to the App!'),
        const SizedBox(height: 16),
        AnimatedTapCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserInfoPage()),
          ),
          child: const _CardContents(
            icon: Icons.person_outline,
            title: 'New or want to change user info?',
            cta: 'Press Here!',
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle('Ready to Workout?'),
        const SizedBox(height: 16),
        AnimatedTapCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkoutTracker()),
          ),
          child: const _CardContents(
            icon: Icons.fitness_center_rounded,
            title: 'Press here!',
            cta: "Let's kill it today",
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle('Water Intake'),
        const SizedBox(height: 16),
        AnimatedTapCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WaterTracker()),
          ),
          child: const _CardContents(
            icon: Icons.water_drop_outlined,
            title: 'How much did you drink?',
            cta: 'Tap Here',
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: AppColors.brand,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _CardContents extends StatelessWidget {
  final IconData icon;
  final String title;
  final String cta;

  const _CardContents({
    required this.icon,
    required this.title,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.brand, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cta,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.brand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.brand,
          size: 28,
        ),
      ],
    );
  }
}
