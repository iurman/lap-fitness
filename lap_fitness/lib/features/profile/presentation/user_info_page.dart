// ignore_for_file: library_private_types_in_public_api, unused_field, prefer_const_constructors, sort_child_properties_last

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/firebase/database_refs.dart';
import '../../auth/data/auth_repository.dart';
import '../../shell/presentation/home_shell.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

class UserInfoPage extends StatefulWidget {
  final String? calories;
  final bool showBackButton; // Add a new parameter to control the back button

  const UserInfoPage({super.key, this.calories, this.showBackButton = false});

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _calorieController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  final List<String> _genders = ['Male', 'Female', 'Non-binary', 'Other'];

  late final _caloriesController = TextEditingController(
      text: widget
          .calories); // Assign the passed calorie amount to a new controller

  final _authRepo = AuthRepository(FirebaseAuth.instance);
  final _profileRepo =
      ProfileRepository(DatabaseRefs(FirebaseDatabase.instance));
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = _authRepo.currentUid!;

    _profileRepo.watchProfile(_uid).listen((profile) {
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
    _ageController.dispose();
    _genderController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose(); // Dispose of the new controller
    _heightInchesController.dispose(); // Dispose of the new controller
    _calorieController.dispose();
    super.dispose();
  }

  void _saveUserInfo() {
    final profile = UserProfile(
      age: _ageController.text,
      gender: _selectedGender ?? '',
      weight: _weightController.text,
      heightFeet: _heightFeetController.text,
      heightInches: _heightInchesController.text,
      calories: _calorieController.text,
    );

    _profileRepo.saveProfile(_uid, profile).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('User info saved successfully.'),
      ));
    }).catchError((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save user info: $error'),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 138, 104, 35),
          title: Text('User Info'),
          automaticallyImplyLeading:
              widget.showBackButton, // Control the back button visibility
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
                  onSaved: (value) {
                    _genderController.text = value ?? '';
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
                // Weight TextFormField
                TextFormField(
                  controller: _weightController, // Add the controller here
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Weight',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(
                          left: 8.0), // Adjust the padding as needed
                      child: Text('lbs'),
                    ),
                  ),
                  // Implement the validator and onSaved logic
                ),

                SizedBox(height: 16),
                Text('Height'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width *
                          0.4, // Adjust the width as needed
                      child: TextFormField(
                        controller:
                            _heightFeetController, // Add the controller here
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Feet',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(
                                left: 8.0), // Adjust the padding as needed
                            child: Text('ft'),
                          ),
                        ),
                        // Implement the validator and onSaved logic
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width *
                          0.4, // Adjust the width as needed
                      child: TextFormField(
                        controller:
                            _heightInchesController, // Add the controller here
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: 'Inches',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(
                                left: 8.0), // Adjust the padding as needed
                            child: Text('in'),
                          ),
                        ),
                        // Implement the validator and onSaved logic
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
                      // Save the user's information
                      _saveUserInfo();

                      // Navigate to the Home page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                        (Route<dynamic> route) => false,
                      );
                    }
                  },
                  child: Text('Save'),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                      Color.fromARGB(255, 138, 104, 35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
