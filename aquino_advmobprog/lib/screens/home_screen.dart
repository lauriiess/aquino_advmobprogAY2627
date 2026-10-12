import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'product_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

import '../widgets/custom_text.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, this.username = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // pages: 0 shop, 1 cart, 2 profile, 3 chat (chat has no footer icon)
  static const int _chatPage = 3;
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // pull the signed-in user's id out of the route arguments (passed by
    // SplashScreen/SignInScreen) so CartScreen renders that user's cart
    final args = ModalRoute.of(context)?.settings.arguments;
    final userData = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    // Firebase accounts have no DummyJSON id (saved as 0), so fall back to
    // the default demo user's cart
    final savedId = userData['id'];
    final userId = (savedId is int && savedId > 0) ? savedId : 5;

    final onChat = _selectedIndex == _chatPage;

    return PopScope(
      canPop: false,
      // back button on the chat list goes back to the shop
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && onChat) _onTappedBar(0);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          backgroundColor: const Color(0xCC8A2BE2), // violet, 80% opacity
          foregroundColor: Colors.white,
          title: (_selectedIndex == 0)
              ? Image.asset('assets/images/nubdexchange_logo.png', scale: 11.sp)
              : CustomText(
                  text: (_selectedIndex == 1)
                      ? 'Cart'
                      : (_selectedIndex == 2)
                          ? 'Profile'
                          : 'Messages',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp, color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          children: <Widget>[
            ProductScreen(userId: userId),
            CartScreen(userId: userId),
            const ProfileScreen(),
            const ChatScreen(),
          ],
          onPageChanged: (page) {
            setState(() {
              _selectedIndex = page;
            });
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false, //selected item
          showUnselectedLabels: false, //unselected item
          // no footer icon is selected while on the chat list
          selectedItemColor: onChat ? Colors.grey : const Color(0xCC8A2BE2),
          unselectedItemColor: Colors.grey,
          onTap: _onTappedBar,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shop_2), label: 'Shop'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: onChat ? 0 : _selectedIndex,
        ),
        // floating chat button opens the chat list, hidden on cart and chat
        floatingActionButton: (_selectedIndex == 1 || onChat)
            ? null
            : FloatingActionButton(
                backgroundColor: const Color(0xCCFF69B4), // pink, 80% opacity
                onPressed: () => _onTappedBar(_chatPage),
                child: const Icon(Icons.chat, color: Colors.white),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  void _onTappedBar(int value) {
    setState(() {
      _selectedIndex = value;
    });
    _pageController.jumpToPage(value);
  }
}