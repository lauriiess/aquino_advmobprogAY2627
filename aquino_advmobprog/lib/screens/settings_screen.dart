import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: 'Settings',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          Card(
            child: SwitchListTile(
              title: CustomText(
                text: 'Dark Mode',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              subtitle: CustomText(
                text: themeProvider.isDark
                    ? 'Dark theme is enabled'
                    : 'Light theme is enabled',
                fontSize: 13.sp,
              ),
              secondary: Icon(
                themeProvider.isDark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              value: themeProvider.isDark,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
            ),
          ),
          // Enhancement 3: logout from settings clears the session (and
          // signs out of Firebase if needed), then goes back to sign in
          SizedBox(height: 8.h),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFE05B5B)),
              title: CustomText(
                text: 'Log Out',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              onTap: () async {
                try {
                  await UserService().logout();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(friendlyError(e))),
                  );
                  return;
                }
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/signin',
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}