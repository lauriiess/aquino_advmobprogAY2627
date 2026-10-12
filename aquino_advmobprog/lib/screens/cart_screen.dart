import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import 'detail_screen.dart';

// Enhancement 1 + 3: this screen shows a user's cart as a list. Tapping an
// item opens the detail screen for it.
// - DummyJSON accounts: cart is loaded from the API (read-only).
// - Firebase accounts: cart is saved in Firestore, so products can be added,
//   quantities changed, items removed and the order confirmed.
//   Products are added from the Products screen.
class CartScreen extends StatefulWidget {
  final int userId;
  const CartScreen({super.key, this.userId = 5});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();

  // which kind of account is logged in (decided once in _init)
  LoginType? _type;
  String? _uid;

  // DummyJSON cart
  late Future<Cart?> _userCartFuture;
  // quantities the user is adjusting on screen, separate from whatever
  // the API originally returned
  List<int> _quantities = [];
  Cart? _cart;

  // Firebase cart (live from Firestore)
  Stream<Cart>? _firebaseStream;

  static const Color _pinkButton = Color.fromARGB(240, 209, 81, 145);
  static const Color _pinkSubtle = Color(0x1EFF69B4);
  static const Color _violet12 = Color(0x1E8A2BE2);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final type = await userService.value.getLoginType();
    if (!mounted) return;

    if (type == LoginType.firebase) {
      _uid = userService.value.currentUser?.uid;
      if (_uid != null) {
        _firebaseStream = _cartService.watchFirebaseCart(_uid!);
      }
    } else {
      _loadCart();
    }
    setState(() => _type = type);
  }

  // ---------------------------------------------------------------------
  // DummyJSON cart
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // Firebase cart actions
  // ---------------------------------------------------------------------

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // runs a Firestore action and shows a friendly message if it fails
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _confirmFirebaseOrder(Cart cart) async {
    await _run(() async {
      await _cartService.checkoutFirebaseCart(_uid!, cart);
      _toast('Order confirmed!');
    });
  }

  // ---------------------------------------------------------------------
  // Shared widgets (used by both cart types)
  // ---------------------------------------------------------------------

  Widget _itemCard({
    required ThemeData theme,
    required bool isDark,
    required CartProduct product,
    required int qty,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    VoidCallback? onRemove, // only Firebase carts can remove items
  }) {
    final lineTotal =
        product.price * (1 - product.discountPercentage / 100) * qty;

    // Enhancement 1: tapping the card takes you to
    // the detail screen for that product
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(product: product),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _violet12),
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
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          color:
                              isDark ? Colors.white70 : Colors.grey.shade600,
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
            // remove button on the left (Firebase only), stepper on the right
            Row(
              children: [
                if (onRemove != null)
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                const Spacer(),
                _stepperButton(
                  context: context,
                  icon: Icons.remove,
                  onTap: onDecrease,
                  filled: false,
                ),
                SizedBox(width: 14.w),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: CustomText(
                    key: ValueKey(qty),
                    text: '$qty',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 14.w),
                _stepperButton(
                  context: context,
                  icon: Icons.add,
                  onTap: onIncrease,
                  filled: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Bottom order summary
  Widget _summary({
    required ThemeData theme,
    required bool isDark,
    required double subtotal,
    required VoidCallback onConfirm,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              Text(
                '\$${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
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
                  borderRadius: BorderRadius.circular(10.r),
                ),
                elevation: 0,
              ),
              onPressed: onConfirm,
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
    );
  }

  Widget _stepperButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Get the current theme so the CartScreen follows light/dark mode.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_type == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_type == LoginType.firebase) {
      return _firebaseBody(theme, isDark);
    }
    return _dummyJsonBody(theme, isDark);
  }

  // ----- Firebase account: cart saved in Firestore -----
  Widget _firebaseBody(ThemeData theme, bool isDark) {
    if (_firebaseStream == null) {
      return Center(
        child: Text(
          'Please log in again to use your cart.',
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        ),
      );
    }

    return StreamBuilder<Cart>(
      stream: _firebaseStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              friendlyError(snapshot.error!),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
          );
        }

        final cart = snapshot.data!;
        final products = cart.products;

        return Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              // header with the add product button
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomText(
                        text: products.isEmpty
                            ? 'My Cart'
                            : 'My Cart (${cart.totalQuantity})',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 44,
                              color: Colors.grey.withOpacity(0.6),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'Your cart is empty',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Add items from the Products screen.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(12.w),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _itemCard(
                            theme: theme,
                            isDark: isDark,
                            product: product,
                            qty: product.quantity,
                            onDecrease: () {
                              if (product.quantity > 1) {
                                _run(() => _cartService.setFirebaseQuantity(
                                    _uid!, product.id, product.quantity - 1));
                              }
                            },
                            onIncrease: () => _run(() =>
                                _cartService.setFirebaseQuantity(
                                    _uid!, product.id, product.quantity + 1)),
                            onRemove: () => _run(() => _cartService
                                .removeFromFirebaseCart(_uid!, product.id)),
                          );
                        },
                      ),
              ),
              if (products.isNotEmpty)
                _summary(
                  theme: theme,
                  isDark: isDark,
                  subtotal: cart.discountedTotal,
                  onConfirm: () => _confirmFirebaseOrder(cart),
                ),
            ],
          ),
        );
      },
    );
  }

  // ----- DummyJSON account: read-only cart from the API -----
  Widget _dummyJsonBody(ThemeData theme, bool isDark) {
    return FutureBuilder<Cart?>(
      future: _userCartFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
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
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
          );
        }

        return Container(
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

                    return _itemCard(
                      theme: theme,
                      isDark: isDark,
                      product: product,
                      qty: qty,
                      onDecrease: () => _decreaseQuantity(index),
                      onIncrease: () => _increaseQuantity(index),
                    );
                  },
                ),
              ),
              _summary(
                theme: theme,
                isDark: isDark,
                subtotal: _subtotal,
                onConfirm: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order confirmed!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}