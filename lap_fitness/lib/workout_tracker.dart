import 'dart:async';
import 'package:flutter/material.dart';

class WorkoutTrackerPage extends StatefulWidget {
  const WorkoutTrackerPage({Key? key}) : super(key: key);

  @override
  _WorkoutTrackerPageState createState() => _WorkoutTrackerPageState();
}

class _WorkoutTrackerPageState extends State<WorkoutTrackerPage> {
  int _currentSet = 1;
  int _currentRep = 1;
  int _currentSeconds = 0;
  bool _isRunning = false;
  late Timer _timer;
  final TextEditingController _repController = TextEditingController();

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentSeconds++;
      });
    });
    setState(() {
      _isRunning = true;
    });
  }

  void _pauseTimer() {
    _timer.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer.cancel();
    setState(() {
      _currentSet = 1;
      _currentRep = 1;
      _currentSeconds = 0;
      _isRunning = false;
    });
  }

  void _nextSet() {
    setState(() {
      _currentSet++;
      _currentRep = 1;
      _currentSeconds = 0;
    });
  }

  void _nextRep(int reps) {
    setState(() {
      _currentRep = reps;
      _currentSeconds = 0;
    });
  }

  void _setReps() {
    // Add this function
    setState(() {
      _currentRep = int.tryParse(_repController.text) ?? 1;
      _repController.text = '';
      _currentSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // Add this override method
    _repController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Set $_currentSet - Rep $_currentRep',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 32),
            Text(
              _formatDuration(_currentSeconds),
              style: TextStyle(fontSize: 48),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  iconSize: 48,
                ),
                SizedBox(width: 32),
                IconButton(
                  onPressed: _resetTimer,
                  icon: Icon(Icons.replay),
                  iconSize: 48,
                ),
                SizedBox(width: 32),
                IconButton(
                  onPressed: _nextSet,
                  icon: Icon(Icons.arrow_forward),
                  iconSize: 48,
                ),
                SizedBox(width: 32),
                IconButton(
                  onPressed: () => _nextRep(_currentRep + 1),
                  icon: Icon(Icons.arrow_upward),
                  iconSize: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
