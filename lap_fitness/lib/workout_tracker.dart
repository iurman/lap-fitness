import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';
import 'core/widgets/primary_button.dart';

class WorkoutTracker extends StatefulWidget {
  const WorkoutTracker({super.key});

  @override
  State<WorkoutTracker> createState() => _WorkoutTrackerState();
}

class _WorkoutTrackerState extends State<WorkoutTracker> {
  static const Map<String, _Workout> _workouts = {
    'push-ups': _Workout('Push-ups', 'assets/images/push-ups.png'),
    'squats': _Workout('Squats', 'assets/images/squats.png'),
    'lunges': _Workout('Lunges', 'assets/images/lunges.png'),
  };

  String _currentWorkoutKey = 'push-ups';
  int _currentSet = 1;
  int _currentRep = 1;
  int _currentSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  final TextEditingController _repController = TextEditingController();

  _Workout get _currentWorkout => _workouts[_currentWorkoutKey]!;

  @override
  void dispose() {
    _timer?.cancel();
    _repController.dispose();
    super.dispose();
  }

  void _selectWorkout(String key) {
    setState(() {
      _currentWorkoutKey = key;
      _currentSet = 1;
      _currentRep = 1;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _currentSeconds++);
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _currentSeconds = 0;
      _isRunning = false;
    });
  }

  void _nextSet() {
    setState(() {
      _currentSet++;
      _currentRep = 1;
    });
  }

  void _setReps() {
    final reps = int.tryParse(_repController.text);
    if (reps != null) setState(() => _currentRep = reps);
    _repController.clear();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final remainingSeconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: 'Workout Tracker',
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _currentWorkoutKey,
              decoration: const InputDecoration(labelText: 'Select a workout'),
              items: _workouts.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value.label),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _selectWorkout(value);
              },
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Container(
                key: ValueKey<String>(_currentWorkoutKey),
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(_currentWorkout.assetPath),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Set $_currentSet · Rep $_currentRep',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _formatDuration(_currentSeconds),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset Timer',
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _isRunning ? 'Pause' : 'Start',
              icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onPressed: _toggleTimer,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _nextSet,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Next Set'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _repController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reps',
                hintText: 'Enter reps for next set',
              ),
              onSubmitted: (_) => _setReps(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Workout {
  final String label;
  final String assetPath;
  const _Workout(this.label, this.assetPath);
}
