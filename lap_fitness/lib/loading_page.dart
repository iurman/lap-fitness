// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:lap_fitness/home_page.dart';
import 'dart:async';

class LoadingPage extends StatefulWidget {
  final String welcomeMessage;

  const LoadingPage({Key? key, required this.welcomeMessage}) : super(key: key);

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();

    Timer(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(widget.welcomeMessage),
      ),
    );
  }
}
