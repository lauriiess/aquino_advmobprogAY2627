import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// Enhancement 3: profile screen, what it shows depends on the LoginType
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  late Future<Map<String, dynamic>> _dataFuture;

  static const Color _violet = Color(0xCC8A2BE2);
  static const Color _pink = Color(0xCCFF69B4);
  static const Color _red = Color(0xFFE05B5B);

  @override
  void initState() {
    super.initState();
    _dataFuture = _userService.getUserData();
  }

  void _reload() {
    // block body on purpose: setState can't take a callback that returns a Future
    setState(() {
      _dataFuture = _userService.getUserData();
    });
  }

  LoginType _typeOf(Map<String, dynamic> data) => LoginType.values.firstWhere(
        (t) => t.name == data['loginType'],
        orElse: () => LoginType.none,
      );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // clear the session then go back to sign in
  Future<void> _logout() async {
    try {
      await _userService.logout();
    } catch (e) {
      _toast(friendlyError(e));
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/signin', (route) => false);
  }

  // account actions (Firebase only)
  Future<void> _updateUsername(String current) async {
    final values = await _askFor(
      title: 'Update username',
      labels: ['New username'],
      initial: [current],
    );
    if (values == null) return;

    final name = values[0].trim();
    if (name.length < 3 || name.contains(' ')) {
      _toast('Username needs 3+ characters and no spaces.');
      return;
    }
    try {
      await _userService.updateUsername(username: name);
      _reload();
      _toast('Username updated.');
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _changePassword(String email) async {
    final values = await _askFor(
      title: 'Change password',
      labels: ['Current password', 'New password'],
      obscure: true,
    );
    if (values == null) return;

    if (values[1].length < 8) {
      _toast('New password must be at least 8 characters.');
      return;
    }
    try {
      await _userService.resetPasswordFromCurrentPassword(
        currentPassword: values[0],
        newPassword: values[1],
        email: email,
      );
      await _userService.refreshFirebaseToken(); // keep the saved token current
      _toast('Password changed.');
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _deleteAccount(String email) async {
    final values = await _askFor(
      title: 'Delete account',
      message: 'This permanently deletes your account. Enter your password to confirm.',
      labels: ['Password'],
      obscure: true,
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (values == null) return;

    try {
      await _userService.deleteAccount(email: email, password: values[0]);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/signin', (route) => false);
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  // simple dialog with one text field per label, returns null if cancelled
  // password fields get an eye button to show or hide what is typed
  Future<List<String>?> _askFor({
    required String title,
    required List<String> labels,
    List<String>? initial,
    String? message,
    bool obscure = false,
    String confirmLabel = 'Save',
    bool destructive = false,
  }) {
    final controllers = [
      for (var i = 0; i < labels.length; i++)
        TextEditingController(text: initial != null ? initial[i] : ''),
    ];
    final hidden = List<bool>.filled(labels.length, obscure);

    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message),
                SizedBox(height: 12.h),
              ],
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 10.h),
                  child: TextField(
                    controller: controllers[i],
                    obscureText: hidden[i],
                    decoration: InputDecoration(
                      labelText: labels[i],
                      suffixIcon: obscure
                          ? IconButton(
                              icon: Icon(
                                hidden[i]
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setDialogState(() => hidden[i] = !hidden[i]),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                  dialogContext, controllers.map((c) => c.text).toList()),
              child: Text(
                confirmLabel,
                style: TextStyle(color: destructive ? _red : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // only show the spinner on the first load, so updates show right away
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null || _typeOf(data) == LoginType.none) {
            return const Center(child: Text('No saved profile data.'));
          }

          final type = _typeOf(data);
          // Firebase accounts show age/contact, DummyJSON shows gender/id
          final isFirebase = type == LoginType.firebase;
          final fullName =
              '${data['firstName']} ${data['lastName']}'.trim();
          final username = data['username'] as String;
          final email = data['email'] as String;
          final image = data['image'] as String;

          return SingleChildScrollView(
            padding: EdgeInsets.all(20.r),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44.r,
                  backgroundColor: _violet.withOpacity(0.15),
                  backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                  child: image.isEmpty
                      ? Icon(Icons.person, size: 44.sp, color: _violet)
                      : null,
                ),
                SizedBox(height: 12.h),
                CustomText(
                  text: fullName.isNotEmpty ? fullName : username,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 2.h),
                Text('@$username',
                    style: TextStyle(fontSize: 13.sp, color: _pink)),
                SizedBox(height: 8.h),
                Chip(
                  avatar: Icon(
                    isFirebase ? Icons.local_fire_department : Icons.api,
                    size: 16,
                  ),
                  label: Text(
                    isFirebase ? 'Signed in with Firebase' : 'Signed in with DummyJSON',
                    style: TextStyle(fontSize: 11.sp),
                  ),
                ),
                SizedBox(height: 16.h),
                _infoTile(Icons.email, 'Email', email),
                if (isFirebase) ...[
                  _infoTile(Icons.cake, 'Age', '${data['age']}'),
                  _infoTile(Icons.phone, 'Contact no.', '${data['contactNo']}'),
                ] else ...[
                  _infoTile(Icons.wc, 'Gender', '${data['gender']}'),
                  _infoTile(Icons.badge, 'User ID', '#${data['id']}'),
                ],
                SizedBox(height: 12.h),
                // only Firebase accounts can edit or delete
                if (isFirebase) ...[
                  _actionTile(Icons.edit, 'Update username',
                      () => _updateUsername(username)),
                  _actionTile(Icons.lock_reset, 'Change password',
                      () => _changePassword(email)),
                  _actionTile(Icons.delete_forever, 'Delete account',
                      () => _deleteAccount(email),
                      color: _red),
                ] else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Text(
                      'Update username, change password and delete account are only available for Firebase accounts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
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

  Widget _infoTile(IconData icon, String label, String value) {
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
          // fixed width so every value lines up
          SizedBox(
            width: 80.w,
            child: CustomText(
                text: label, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
          // scaleDown shrinks long values (like emails) to fit on one line
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
      leading: Icon(icon, color: color ?? _violet),
      title: Text(label, style: TextStyle(color: color, fontSize: 14.sp)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}