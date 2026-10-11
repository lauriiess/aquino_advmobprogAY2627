import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// Enhancement 2: sign up screen, creates a Firebase account
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final UserService _userService = UserService();
  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  static const Color _violet = Color(0xCC8A2BE2);
  final TextStyle _inputStyle = TextStyle(fontSize: 13.sp);

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _ageCtrl,
      _contactCtrl,
      _usernameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label is required' : null;

  // age must be a number from 13 to 120
  String? _validateAge(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    if (age == null) return 'Enter your age as a number';
    if (age < 13 || age > 120) return 'Age must be between 13 and 120';
    return null;
  }

  // digits only, exactly 11
  String? _validateContact(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Contact number is required';
    if (text.length != 11) return 'Contact number must be 11 digits';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // password rules: length, upper, lower, number, symbol
  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'At least 8 characters';
    if (!text.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
    if (!text.contains(RegExp(r'[a-z]'))) return 'Add a lowercase letter';
    if (!text.contains(RegExp(r'\d'))) return 'Add a number';
    if (!text.contains(RegExp(r'[^A-Za-z0-9]'))) return 'Add a special character';
    return null;
  }

  // creates the account, then saves the extra details
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _userService.createAccount(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await _userService.saveSignupDetails(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        age: int.parse(_ageCtrl.text.trim()),
        contactNo: _contactCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
      );

      final userData = await _userService.getUserData();
      if (!mounted) return;
      // already signed in after sign up, so go to home
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
        arguments: userData,
      );
    } catch (e) {
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      prefixIcon: Icon(icon, size: 20.sp),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
    );
  }

  Widget _gap() => SizedBox(height: 16.h);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: 'Create Account',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        // Center keeps the form in the middle of the screen
        child: Center(
          child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  style: _inputStyle,
                  controller: _firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('First name', Icons.person),
                  validator: (v) => _required(v, 'First name'),
                ),
                _gap(),
                TextFormField(
                  style: _inputStyle,
                  controller: _lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Last name', Icons.person_outline),
                  validator: (v) => _required(v, 'Last name'),
                ),
                _gap(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        style: _inputStyle,
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _decoration('Age', Icons.cake),
                        validator: _validateAge,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        style: _inputStyle,
                        controller: _contactCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: _decoration('Contact no.', Icons.phone),
                        validator: _validateContact,
                      ),
                    ),
                  ],
                ),
                _gap(),
                TextFormField(
                        style: _inputStyle,
                  controller: _usernameCtrl,
                  decoration: _decoration('Username', Icons.alternate_email),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.length < 3) return 'At least 3 characters';
                    if (text.contains(' ')) return 'No spaces allowed';
                    return null;
                  },
                ),
                _gap(),
                TextFormField(
                        style: _inputStyle,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('Email address', Icons.email),
                  validator: _validateEmail,
                ),
                _gap(),
                TextFormField(
                        style: _inputStyle,
                  controller: _passwordCtrl,
                  obscureText: _hidePassword,
                  decoration: _decoration(
                    'Password',
                    Icons.lock,
                    suffix: IconButton(
                      icon: Icon(
                        _hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                SizedBox(height: 4.h),
                Text(
                  '8+ characters with upper and lower case, a number and a symbol.',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                ),
                _gap(),
                TextFormField(
                        style: _inputStyle,
                  controller: _confirmCtrl,
                  obscureText: _hideConfirm,
                  decoration: _decoration(
                    'Confirm password',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _hideConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _hideConfirm = !_hideConfirm),
                    ),
                  ),
                  validator: (v) =>
                      v != _passwordCtrl.text ? 'Passwords do not match' : null,
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  height: 42.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _violet,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?',
                        style: TextStyle(fontSize: 12.sp)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}