import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import 'chat_detailscreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _violet = Color(0xFF8A2BE2);

  final TextEditingController _searchChatController = TextEditingController();
  final ChatService _chatService = ChatService();
  late final Stream<List<Map<String, dynamic>>> _usersStream;
  String? _currentUserEmail;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    // create the stream once so typing in search doesn't restart it
    _usersStream = _chatService.getUsersStream();
    _loadCurrentUserEmail();
  }

  Future<void> _loadCurrentUserEmail() async {
    final userData = await userService.value.getUserData();
    if (!mounted) return;
    setState(() {
      _currentUserEmail = userData['email'];
    });
  }

  @override
  void dispose() {
    _searchChatController.dispose();
    super.dispose();
  }

  // keeps users whose name or email contains the search text
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((user) {
      final fields = [
        ChatService.displayName(user),
        user['firstName'],
        user['lastName'],
        user['username'],
        user['email'],
      ];
      return fields.any((f) => (f ?? '').toString().toLowerCase().contains(query));
    }).toList();
  }

  // centered message used for loading, error and empty states
  Widget _centerMessage(Widget child, {IconData? icon}) {
    return _FadeSlideIn(
      child: Container(
        height: ScreenUtil().screenHeight * 0.5,
        padding: EdgeInsets.all(16.sp),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 40, color: Colors.grey.withOpacity(0.6)),
                const SizedBox(height: 10),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }

  Route _chatRoute(Map<String, dynamic> user) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, __) => ChatDetailScreen(
        currentUserEmail: _currentUserEmail ?? '',
        tappedUser: user,
      ),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _searchBar(bool isDark) {
    final fill = isDark ? const Color(0xFF2B2D33) : const Color(0xFFF2F2F5);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: TextField(
        controller: _searchChatController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _searchText = value),
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          filled: true,
          fillColor: fill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _searchChatController.text.isNotEmpty
                ? IconButton(
                    key: const ValueKey('clear'),
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      setState(() {
                        _searchChatController.clear();
                        _searchText = '';
                      });
                    },
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _violet, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, bool isDark) {
    final name = ChatService.displayName(user);
    final uid = (user['uid'] ?? '').toString();
    final surface = isDark ? const Color(0xFF1F2025) : Colors.white;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4),
      child: Material(
        color: surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(isDark ? 0.18 : 0.2)),
        ),
        child: InkWell(
          // open the conversation with this user
          onTap: () => Navigator.push(context, _chatRoute(user)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                UserAvatar(tag: 'avatar_$uid', name: name, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: name,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 2),
                      CustomText(
                        text: user['email'] ?? 'No email',
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.withOpacity(0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          SizedBox(height: 20.h),
          _searchBar(isDark),
          SizedBox(height: 12.h),
          // Users Stream
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _centerMessage(
                  const CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError) {
                return _centerMessage(
                  CustomText(text: 'Error loading users', fontSize: 16.sp),
                  icon: Icons.error_outline_rounded,
                );
              }
              final allUsers = snapshot.data ?? [];
              if (allUsers.isEmpty) {
                return _centerMessage(
                  CustomText(text: 'No users found!', fontSize: 16.sp),
                  icon: Icons.people_outline_rounded,
                );
              }

              final users = _filterUsers(allUsers);
              if (users.isEmpty) {
                return _centerMessage(
                  CustomText(
                    text: 'No results for "${_searchText.trim()}"',
                    fontSize: 16.sp,
                  ),
                  icon: Icons.search_off_rounded,
                );
              }

              return Column(
                children: [
                  // count of users or search results
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: CustomText(
                          key: ValueKey('${_searchText.trim().isEmpty}-${users.length}'),
                          text: _searchText.trim().isEmpty
                              ? '${users.length} user(s)'
                              : '${users.length} result(s)',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(bottom: 16.h),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final uid = (user['uid'] ?? user['email'] ?? index).toString();
                      // keyed by user so already-shown rows don't replay when filtering
                      return _FadeSlideIn(
                        key: ValueKey(uid),
                        delay: Duration(milliseconds: 45 * (index > 8 ? 8 : index)),
                        child: _userTile(user, isDark),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// plays a short fade + slide up once when first built (optionally delayed)
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _dur = 380;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final total = _dur + widget.delay.inMilliseconds;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(
        widget.delay.inMilliseconds / total,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_anim),
        child: widget.child,
      ),
    );
  }
}