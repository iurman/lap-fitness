// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, unused_field, prefer_final_fields, prefer_const_constructors, unused_element, prefer_const_literals_to_create_immutables, sort_child_properties_last
// ignore_for_file: unused_import

import 'dart:async';
import 'package:flutter/material.dart';

class WorkoutTracker extends StatefulWidget {
  @override
  _WorkoutTrackerState createState() => _WorkoutTrackerState();
}

class _WorkoutTrackerState extends State<WorkoutTracker> {
  String _currentWorkout = 'Push-ups';
  String _currentImage = 'assets/images/push-ups.png';
  int _currentSet = 1;
  int _currentRep = 1;
  int _currentSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  TextEditingController _repController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _repController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentSeconds++;
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
    });

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

  void _nextRep(int rep) {
    setState(() {
      _currentRep = rep;
    });
  }

  void _setReps() {
    final reps = int.tryParse(_repController.text);

    if (reps != null) {
      setState(() {
        _currentRep = reps;
      });
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
      appBar: AppBar(
        title: Text('Workout Tracker'),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select a workout',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'push-ups',
                    child: Text('Push-ups'),
                  ),
                  DropdownMenuItem(
                    value: 'squats',
                    child: Text('Squats'),
                  ),
                  DropdownMenuItem(
                    value: 'lunges',
                    child: Text('Lunges'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _currentWorkout = value!;
                    switch (value) {
                      case 'push-ups':
                        _currentImage = 'assets/images/push-ups.png';
                        _currentSet = 1;
                        _currentRep = 1;
                        break;
                      case 'squats':
                        _currentImage = 'assets/images/squats.png';
                        _currentSet = 1;
                        _currentRep = 1;
                        break;
                      case 'lunges':
                        _currentImage = 'assets/images/lunges.png';
                        _currentSet = 1;
                        _currentRep = 1;
                    }
                  });
                },
              ),
              SizedBox(height: 16),
              Image.asset(
                _currentImage,
                height: 200,
              ),
              SizedBox(height: 16),
              Text(
                'Set $_currentSet - Rep $_currentRep',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 32),
              Text(
                _formatDuration(_currentSeconds),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48),
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _resetTimer();
                    },
                    icon: Icon(Icons.refresh),
                    tooltip: 'Reset Timer',
                  ),
                ],
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                child: Text(_isRunning ? 'Pause' : 'Start'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    Color.fromARGB(255, 138, 104, 35),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _nextSet,
                child: Text('Next Set'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    Color.fromARGB(255, 138, 104, 35),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _repController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Reps',
                  hintText: 'Enter reps for next set',
                ),
                onSubmitted: (value) {
                  _setReps();
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
