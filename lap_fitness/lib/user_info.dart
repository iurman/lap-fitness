import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';
import 'data/user_repository.dart';
import 'home_page.dart';

class UserInfoPage extends StatefulWidget {
  final String? calories;
  final bool showBackButton;

  const UserInfoPage({Key? key, this.calories, this.showBackButton = false})
      : super(key: key);

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  static const List<String> _genders = [
    'Male',
    'Female',
    'Non-binary',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  late final _calorieController =
      TextEditingController(text: widget.calories ?? '');

  final UserRepository _users = UserRepository();
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _hydrateFromProfile();
  }

  Future<void> _hydrateFromProfile() async {
    try {
      final profile = await _users.fetchProfile();
      if (!mounted) return;
      setState(() {
        _ageController.text = profile.age ?? '';
        _selectedGender = (profile.gender?.isNotEmpty ?? false)
            ? profile.gender
            : null;
        _weightController.text = profile.weight ?? '';
        _heightFeetController.text = profile.heightFeet ?? '';
        _heightInchesController.text = profile.heightInches ?? '';
        if (profile.calories != null && profile.calories!.isNotEmpty) {
          _calorieController.text = profile.calories!;
        }
      });
    } catch (_) {/* leave controllers empty */}
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  Future<void> _saveUserInfo() async {
    try {
      await _users.updateProfile(
        age: _ageController.text,
        gender: _selectedGender,
        weight: _weightController.text,
        heightFeet: _heightFeetController.text,
        heightInches: _heightInchesController.text,
        calories: _calorieController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User info saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save user info: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: 'User Info',
        automaticallyImplyLeading: widget.showBackButton,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Age'),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                hint: const Text('Select Gender'),
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your gender';
                  }
                  return null;
                },
                items: _genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text('Weight'),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'Weight',
                  suffixIcon: Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text('lbs'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Height'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: TextFormField(
                      controller: _heightFeetController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Feet',
                        suffixIcon: Padding(
                          padding: EdgeInsets.only(left: 8.0),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Inches',
                        suffixIcon: Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text('in'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Target Calories'),
              TextFormField(
                controller: _calorieController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  await _saveUserInfo();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
