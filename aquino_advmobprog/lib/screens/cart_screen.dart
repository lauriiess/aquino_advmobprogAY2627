import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import 'detail_screen.dart';

// Enhancement 1 + 3: this screen loads one user's cart from the API and
// shows it as a list. Tapping an item opens the detail screen for it.
class CartScreen extends StatefulWidget {
  final int userId;
  const CartScreen({super.key, this.userId = 5});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  late Future<Cart?> _userCartFuture;

  // quantities the user is adjusting on screen, separate from whatever
  // the API originally returned
  List<int> _quantities = [];
  Cart? _cart;

  static const Color _pinkButton = Color.fromARGB(240, 209, 81, 145);
  static const Color _pinkSubtle = Color(0x1EFF69B4);
  static const Color _violet12 = Color(0x1E8A2BE2);

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  // Enhancement 3: fetch the cart for this specific user using the
  // /carts/user/{id} endpoint. Split out so the Retry button can call it
  // again after a transient network error.
  void _loadCart() {
    _userCartFuture = _cartService.getCartByUserId(widget.userId);

    _userCartFuture.then((cart) {
      // Bug fix: this future can resolve after the widget has already
      // been disposed (e.g. navigating away while the request is still
      // in flight), so guard with `mounted` before calling setState.
      if (!mounted) return;
      if (cart != null) {
        setState(() {
          _cart = cart;
          _quantities = cart.products.map((p) => p.quantity).toList();
        });
      }
    }).catchError((_) {
      // FutureBuilder below already surfaces this error to the UI --
      // swallow it here so it doesn't also print as an unhandled
      // Future exception in the console.
    });
  }

  double get _subtotal {
    if (_cart == null) return 0;

    double sum = 0;

    for (int i = 0; i < _cart!.products.length; i++) {
      final product = _cart!.products[i];

      final discountedPrice =
          product.price * (1 - product.discountPercentage / 100);

      sum += discountedPrice * _quantities[i];
    }

    return sum;
  }

  void _increaseQuantity(int index) async {
    setState(() => _quantities[index]++);

    // Enhancement 3: also try out the add-to-cart endpoint
    final product = _cart!.products[index];

    try {
      await _cartService.addToCart(
        userId: widget.userId,
        products: [
          {
            'id': product.id,
            'quantity': _quantities[index],
          },
        ],
      );
    } catch (_) {
      // dummyjson doesn't really save this, so we just ignore failures here
    }
  }

  void _decreaseQuantity(int index) {
    if (_quantities[index] > 1) {
      setState(() => _quantities[index]--);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme so the CartScreen follows light/dark mode.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<Cart?>(
      future: _userCartFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          // Bug fix: dummyjson occasionally resets the connection on the
          // first request. A Retry button lets the user recover without
          // reloading the whole app.
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  friendlyError(snapshot.error!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: () => setState(_loadCart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pinkButton,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        final cart = snapshot.data;

        if (cart == null || cart.products.isEmpty) {
          return Center(
            child: Text(
              'Your cart is empty',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          );
        }

        return Container(
          // Changed from hardcoded light background
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(12.w),
                  itemCount: cart.products.length,
                  itemBuilder: (context, index) {
                    final product = cart.products[index];

                    final qty = _quantities.isNotEmpty
                        ? _quantities[index]
                        : product.quantity;

                    final lineTotal =
                        product.price *
                            (1 - product.discountPercentage / 100) *
                            qty;

                    // Enhancement 1: tapping the card takes you to
                    // the detail screen for that product
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetailScreen(product: product),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          // Changed from Colors.white
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: _violet12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Circular thumbnail
                                ClipOval(
                                  child: Image.network(
                                    product.thumbnail,
                                    width: 48.w,
                                    height: 48.w,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.broken_image,
                                    ),
                                  ),
                                ),

                                SizedBox(width: 10.w),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CustomText(
                                        text: product.title,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                      ),

                                      SizedBox(height: 2.h),

                                      Text(
                                        '${product.discountPercentage.toStringAsFixed(0)}% off • \$${lineTotal.toStringAsFixed(2)} total',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Text(
                                  '\$${product.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: _pinkButton,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 8.h),

                            // Horizontal stepper
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _stepperButton(
                                  context: context,
                                  icon: Icons.remove,
                                  onTap: () =>
                                      _decreaseQuantity(index),
                                  filled: false,
                                ),

                                SizedBox(width: 14.w),

                                CustomText(
                                  text: '$qty',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),

                                SizedBox(width: 14.w),

                                _stepperButton(
                                  context: context,
                                  icon: Icons.add,
                                  onTap: () =>
                                      _increaseQuantity(index),
                                  filled: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom order summary
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                decoration: BoxDecoration(
                  // Changed from Colors.white
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        isDark ? 0.3 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),

                        Text(
                          '\$${_subtotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 3.h),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delivery Fee',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),

                        Text(
                          'Free',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pinkButton,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order confirmed!'),
                            ),
                          );
                        },
                        child: Text(
                          'Confirm Order',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stepperButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26.w,
        height: 26.w,
        decoration: BoxDecoration(
          color: filled ? _pinkButton : _pinkSubtle,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled
              ? Colors.white
              : isDark
                  ? Colors.white70
                  : Colors.black54,
        ),
      ),
    );
  }
}