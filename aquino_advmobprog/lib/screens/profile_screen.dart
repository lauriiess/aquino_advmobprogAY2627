import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import 'signin_screen.dart';

// Enhancement 3: reads the signed-in user's data (persisted by
// UserService/SharedPreferences) through the User model and renders it
// here. Logging out clears the session and returns to the sign in screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  late Future<User> _userFuture;

  static const Color _violet = Color(0xCC8A2BE2);
  static const Color _pink = Color(0xCCFF69B4);

  @override
  void initState() {
    super.initState();
    _userFuture = _userService.getUser();
  }

  Future<void> _logout() async {
    await _userService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;

          if (user == null || user.username.isEmpty) {
            return const Center(child: Text('No saved profile data.'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(20.r),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44.r,
                  backgroundColor: _violet.withOpacity(0.15),
                  backgroundImage:
                      user.image.isNotEmpty ? NetworkImage(user.image) : null,
                  child: user.image.isEmpty
                      ? Icon(Icons.person, size: 44.sp, color: _violet)
                      : null,
                ),
                SizedBox(height: 12.h),
                CustomText(
                  text: user.fullName.isNotEmpty ? user.fullName : user.username,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 2.h),
                Text(
                  '@${user.username}',
                  style: TextStyle(fontSize: 13.sp, color: _pink),
                ),
                SizedBox(height: 20.h),
                _infoTile(icon: Icons.email, label: 'Email', value: user.email),
                _infoTile(icon: Icons.wc, label: 'Gender', value: user.gender),
                _infoTile(icon: Icons.badge, label: 'User ID', value: '#${user.id}'),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE05B5B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: Text(
                      'Log Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: _violet.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: _violet),
          SizedBox(width: 12.w),
          CustomText(text: label, fontSize: 12.sp, fontWeight: FontWeight.w500),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
