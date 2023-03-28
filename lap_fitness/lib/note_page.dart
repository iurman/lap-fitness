// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

class NotePage extends StatelessWidget {
  const NotePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
      ),
      body: Center(
        child: Text('Notes Page'),
      ),
    );
  }
}
