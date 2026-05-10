import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';
import 'data/water_repository.dart';

class WaterTracker extends StatefulWidget {
  const WaterTracker({super.key});

  @override
  State<WaterTracker> createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker> {
  static const int _dailyGoal = 8;

  final WaterRepository _repo = WaterRepository();
  int _waterIntake = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIntake();
  }

  Future<void> _loadIntake() async {
    try {
      final value = await _repo.fetchIntake();
      if (!mounted) return;
      setState(() {
        _waterIntake = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    try {
      await _repo.setIntake(_waterIntake);
    } catch (_) {/* swallow */}
  }

  void _increment() {
    setState(() => _waterIntake++);
    _persist();
  }

  void _decrement() {
    if (_waterIntake == 0) return;
    setState(() => _waterIntake--);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_waterIntake / _dailyGoal).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      appBar: const BrandAppBar(title: 'Water Intake'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              backgroundColor:
                                  AppColors.brand.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/images/water_bottle.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        '$_waterIntake',
                        key: ValueKey<int>(_waterIntake),
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                    Text(
                      'cups of $_dailyGoal',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CounterButton(
                          icon: Icons.remove_rounded,
                          onPressed: _waterIntake == 0 ? null : _decrement,
                          heroTag: 'water_dec',
                        ),
                        const SizedBox(width: 32),
                        _CounterButton(
                          icon: Icons.add_rounded,
                          onPressed: _increment,
                          heroTag: 'water_inc',
                          filled: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String heroTag;
  final bool filled;

  const _CounterButton({
    required this.icon,
    required this.onPressed,
    required this.heroTag,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: onPressed == null ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: filled ? AppColors.brand : Colors.white,
        foregroundColor: filled ? Colors.white : AppColors.brand,
        elevation: filled ? 4 : 1,
        shape: const CircleBorder(),
        child: Icon(icon, size: 28),
      ),
    );
  }
}
