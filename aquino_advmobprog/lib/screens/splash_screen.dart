import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/user_service.dart';

// Enhancement 1: custom splash screen UI. On start, it checks
// SharedPreferences (through UserService.isLoggedIn()) for a persisted
// session -- if one exists it goes straight to /home with the saved
// user data, otherwise it sends the user to /signin.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final loggedIn = await _userService.isLoggedIn();

    if (!mounted) return;

    if (loggedIn) {
      final userData = await _userService.getUserData();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: userData,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xCC8A2BE2), // violet, 80% opacity
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/nubdexchange_logo.png',
              width: 140.w,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.storefront,
                size: 96.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'NUBD Exchange',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32.h),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
