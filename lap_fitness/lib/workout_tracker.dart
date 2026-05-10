import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';

class WorkoutTracker extends StatefulWidget {
  const WorkoutTracker({Key? key}) : super(key: key);

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

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentSeconds++);
    });
  }

  void _pauseTimer() {
    setState(() => _isRunning = false);
    _timer?.cancel();
  }

  void _resetTimer() {
    setState(() {
      _currentSeconds = 0;
      _isRunning = false;
    });
    _timer?.cancel();
  }

  void _nextSet() {
    setState(() {
      _currentSet++;
      _currentRep = 1;
    });
  }

  void _setReps() {
    final reps = int.tryParse(_repController.text);
    if (reps != null) {
      setState(() => _currentRep = reps);
    }
    _repController.clear();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              const SizedBox(height: 16),
              Image.asset(_currentWorkout.assetPath, height: 200),
              const SizedBox(height: 16),
              Text(
                'Set $_currentSet - Rep $_currentRep',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 32),
              Text(
                _formatDuration(_currentSeconds),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset Timer',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                child: Text(_isRunning ? 'Pause' : 'Start'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
                onPressed: _nextSet,
                child: const Text('Next Set'),
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
              const SizedBox(height: 16),
            ],
          ),
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
