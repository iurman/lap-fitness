import 'package:flutter/material.dart';

import 'core/widgets/brand_app_bar.dart';
import 'data/water_repository.dart';

class WaterTracker extends StatefulWidget {
  const WaterTracker({Key? key}) : super(key: key);

  @override
  State<WaterTracker> createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker> {
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
    return Scaffold(
      appBar: const BrandAppBar(title: 'Water Intake Tracker'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Image.asset(
                        'assets/images/water_bottle.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Water Intake: $_waterIntake cups',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        onPressed: _decrement,
                        heroTag: 'water_dec',
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        onPressed: _increment,
                        heroTag: 'water_inc',
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
