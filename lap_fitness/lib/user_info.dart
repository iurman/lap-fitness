// ignore_for_file: library_private_types_in_public_api, unused_field, deprecated_member_use, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lap_fitness/home_page.dart';
import 'package:flutter/services.dart';

class UserInfoPage extends StatefulWidget {
  final String? calories;
  final bool showBackButton; // Add a new parameter to control the back button

  const UserInfoPage({Key? key, this.calories, this.showBackButton = false})
      : super(key: key);

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

  late DatabaseReference _userRef;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _userRef = FirebaseDatabase.instance
        .reference()
        .child('users')
        .child(_currentUser.uid);

    _userRef.onValue.listen((event) {
      final user = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _ageController.text = user['age'] ?? '';
        _selectedGender =
            user['gender'] ?? ''; // Update _selectedGender instead
        _weightController.text = user['weight'] ?? '';
        _heightFeetController.text = user['heightFeet'] ?? '';
        _heightInchesController.text = user['heightInches'] ?? '';
        _calorieController.text = user['calories'] ?? '';
      });
    }, onError: (error) {
      // handle error
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
    // Get the form values
    final age = _ageController.text;
    final gender = _selectedGender;
    final weight = _weightController.text;
    final heightFeet = _heightFeetController.text;
    final heightInches = _heightInchesController.text;
    final calories = _calorieController.text;

    // Save the user info to the database
    _userRef.update({
      'age': age,
      'gender': gender,
      'weight': weight,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'calories': calories,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('User info saved successfully.'),
      ));
    }).catchError((error) {
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
