// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors, sized_box_for_whitespace

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/water_repository.dart';

class WaterTracker extends ConsumerStatefulWidget {
  @override
  ConsumerState<WaterTracker> createState() => _WaterTrackerState();
}

class _WaterTrackerState extends ConsumerState<WaterTracker> {
  int _waterIntake = 0;
  late final String _uid;
  StreamSubscription<int>? _intakeSub;

  WaterRepository get _waterRepo => ref.read(waterRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUid!;
    _intakeSub = _waterRepo.watchIntake(_uid).listen((cups) {
      if (mounted) setState(() => _waterIntake = cups);
    });
  }

  @override
  void dispose() {
    _intakeSub?.cancel();
    super.dispose();
  }

  // The displayed count is driven entirely by the watchIntake stream; taps just
  // request an atomic adjustment so concurrent taps can't lose updates.
  void _incrementWaterIntake() => unawaited(_waterRepo.adjust(_uid, 1));

  void _decrementWaterIntake() => unawaited(_waterRepo.adjust(_uid, -1));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        title: Text('Water Intake Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 200,
              child: Stack(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/water_bottle.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Water Intake: $_waterIntake cups',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: _decrementWaterIntake,
                  child: Icon(Icons.remove),
                ),
                SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _incrementWaterIntake,
                  child: Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
