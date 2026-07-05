// ignore_for_file: prefer_const_constructors, sort_child_properties_last

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../domain/user_profile.dart';

class UserInfoPage extends ConsumerStatefulWidget {
  /// When true this is the first-time onboarding flow (no back button, saving
  /// advances to home). When false it edits an existing profile (has a back
  /// button, saving pops).
  final bool isOnboarding;

  const UserInfoPage({super.key, this.isOnboarding = false});

  @override
  ConsumerState<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends ConsumerState<UserInfoPage> {
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _calorieController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  final List<String> _genders = ['Male', 'Female', 'Non-binary', 'Other'];

  late final String _uid;
  StreamSubscription<UserProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUid!;

    _profileSub = ref
        .read(profileRepositoryProvider)
        .watchProfile(_uid)
        .listen((profile) {
      if (!mounted) return;
      setState(() {
        _ageController.text = profile.age;
        _selectedGender = profile.gender.isEmpty ? null : profile.gender;
        _weightController.text = profile.weight;
        _heightFeetController.text = profile.heightFeet;
        _heightInchesController.text = profile.heightInches;
        _calorieController.text = profile.calories;
      });
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _ageController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  Future<void> _saveUserInfo() async {
    final profile = UserProfile(
      age: _ageController.text,
      gender: _selectedGender ?? '',
      weight: _weightController.text,
      heightFeet: _heightFeetController.text,
      heightInches: _heightInchesController.text,
      calories: _calorieController.text,
    );

    try {
      await ref.read(profileRepositoryProvider).saveProfile(_uid, profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('User info saved successfully.'),
      ));
      if (widget.isOnboarding) {
        context.go(Routes.home);
      } else {
        context.pop();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save user info: $error'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.brand,
          title: Text('User Info'),
          automaticallyImplyLeading: !widget.isOnboarding,
        ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Age'),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // `value` keeps this dropdown controlled so it reflects the
                  // profile loaded asynchronously; initialValue would only apply
                  // once and miss the prefill.
                  // ignore: deprecated_member_use
                  value: _selectedGender,
                  hint: Text('Select Gender'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                  items: _genders.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                Text('Weight'),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Weight',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text('lbs'),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text('Height'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: TextFormField(
                        controller: _heightFeetController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Feet',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text('ft'),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: TextFormField(
                        controller: _heightInchesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Inches',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text('in'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text('Target Calories'),
                TextFormField(
                  controller: _calorieController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _saveUserInfo();
                    }
                  },
                  child: Text('Save'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
