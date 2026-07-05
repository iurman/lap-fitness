// ignore_for_file: prefer_const_constructors
// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ProfileSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        title: Text('Profile Settings'),
      ),
      body: Center(
        child: Text('Profile Settings Page'),
      ),
    );
  }
}
