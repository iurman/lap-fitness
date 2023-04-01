import 'package:flutter/material.dart';

class PrivacySettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        title: Text('Privacy Settings'),
      ),
      body: Center(
        child: Text('Privacy Settings Page'),
      ),
    );
  }
}
