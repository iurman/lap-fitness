import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lap_fitness/home_page.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
        _genderController.text = user['gender'] ?? '';
        _weightController.text = user['weight'] ?? '';
        _heightController.text = user['height'] ?? '';
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
    _heightController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  void _saveUserInfo() {
    // Get the form values
    final age = _ageController.text;
    final gender = _genderController.text;
    final weight = _weightController.text;
    final height = _heightController.text;
    final calories = _calorieController.text;

    // Save the user info to the database
    _userRef.update({
      'age': age,
      'gender': gender,
      'weight': weight,
      'height': height,
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
                Text('Gender'),
                TextFormField(
                  controller: _genderController,
                ),
                SizedBox(height: 16),
                Text('Weight'),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                Text('Height'),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                Text('Target Calories'),
                TextFormField(
                  controller: _calorieController,
                  keyboardType: TextInputType.number,
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
                )
              ],
            ),
          ),
        ));
  }
}
