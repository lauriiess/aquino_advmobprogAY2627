import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'product_screen.dart';
import 'cart_screen.dart';

import '../widgets/custom_text.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, this.username = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        // background is violet now (kept at 80% opacity, not solid) -- this
        // is also the only title bar the app shows, CartScreen used to have
        // its own AppBar too, which stacked two bars on top of each other
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          backgroundColor: const Color(0xCC8A2BE2), // violet, 80% opacity
          foregroundColor: Colors.white,
          title: (_selectedIndex == 0)
              ? Image.asset('assets/images/nubdexchange_logo.png' , scale: 11.sp,)
              : CustomText(
                  text: (_selectedIndex == 1)
                      ? 'Cart'
                      : (_selectedIndex == 2)
                          ? 'Profile'
                          : 'Home',
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
          children: const <Widget>[
            ProductScreen(),
            CartScreen(),
            Center(child: Text('Profile')),
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
          selectedItemColor: const Color(0xCC8A2BE2), // violet, 80% opacity
          unselectedItemColor: Colors.grey,
          onTap: _onTappedBar,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shop_2), label: 'Shop'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
        ),
        // Enhancement 2: turned the chat button into a floating action
        // button instead of a bottom nav item, and it just disappears
        // while on the Cart tab (index 1) 
        floatingActionButton: (_selectedIndex == 1)
            ? null
            : FloatingActionButton(
                backgroundColor: const Color(0xCCFF69B4), // pink, 80% opacity
                onPressed: () {
                  // no chat screen built yet in this project, so just
                  // showing a snackbar for now instead of navigating
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat screen not implemented yet')),
                  );
                },
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