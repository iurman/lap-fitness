import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/widgets/brand_app_bar.dart';
import 'core/widgets/primary_button.dart';
import 'data/user_repository.dart';
import 'home_page.dart';

class UserInfoPage extends StatefulWidget {
  final String? calories;
  final bool showBackButton;

  const UserInfoPage({super.key, this.calories, this.showBackButton = false});

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
  bool _saving = false;

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
    } catch (_) {/* leave blank */}
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
    setState(() => _saving = true);
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: BrandAppBar(
        title: 'User Info',
        automaticallyImplyLeading: widget.showBackButton,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration:
                          const InputDecoration(labelText: 'Gender'),
                      hint: const Text('Select gender'),
                      onChanged: (value) =>
                          setState(() => _selectedGender = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                      items: _genders
                          .map((g) =>
                              DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        suffixText: 'lbs',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightFeetController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              suffixText: 'ft',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _heightInchesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: ' ',
                              suffixText: 'in',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _calorieController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Target Calories',
                        suffixText: 'cal',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      await _saveUserInfo();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
