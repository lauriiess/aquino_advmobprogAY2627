import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// Enhancement 2: sign in screen with DummyJSON and Firebase options
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  LoginType _loginType = LoginType.dummyJson;

  bool get _isFirebase => _loginType == LoginType.firebase;

  static const Color _violet = Color(0xCC8A2BE2);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // logs in using DummyJSON or Firebase, depending on the toggle
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final userService = UserService();
    setState(() => _isLoading = true);

    try {
      if (_isFirebase) {
        await userService.signIn(
          email: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await userService.loginUser(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }

      // both paths leave the session in SharedPreferences, so read it back
      // both logins save to SharedPreferences, so read it back here
      final userData = await userService.getUserData();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: userData);
    } catch (e) {
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/nubdexchange_logo.png',
                    width: 90.w,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.storefront, size: 70.sp, color: _violet),
                  ),
                ),
                SizedBox(height: 12.h),
                Center(
                  child: CustomText(
                    text: 'Welcome to NUBD Exchange',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24.h),
                // switch between DummyJSON and Firebase login
                SegmentedButton<LoginType>(
                  segments: const [
                    ButtonSegment(
                      value: LoginType.dummyJson,
                      icon: Icon(Icons.api),
                      label: Text('DummyJSON'),
                    ),
                    ButtonSegment(
                      value: LoginType.firebase,
                      icon: Icon(Icons.local_fire_department),
                      label: Text('Firebase'),
                    ),
                  ],
                  selected: {_loginType},
                  onSelectionChanged: (selection) {
                    setState(() => _loginType = selection.first);
                    _formKey.currentState?.reset();
                  },
                ),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: _usernameController,
                  keyboardType: _isFirebase
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: _isFirebase ? 'Email' : 'Username',
                    prefixIcon: Icon(_isFirebase ? Icons.email : Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return _isFirebase
                          ? 'Email is required'
                          : 'Username is required';
                    }
                    if (_isFirebase && !text.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Password is required'
                      : null,
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  height: 46.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _violet,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: _isLoading ? null : _login,
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
                            'Log In',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // link to the sign up screen
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }
}