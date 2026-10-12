import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final int userId;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.userId = 5,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const Color _pinkButton = Color.fromARGB(240, 209, 81, 145);

  final CartService _cartService = CartService();
  int _quantity = 1;
  bool _adding = false;

  // Firebase accounts save the cart in Firestore, DummyJSON accounts keep
  // using the /carts/add test endpoint
  bool _isFirebase = false;
  String? _uid;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final type = await userService.value.getLoginType();
    if (!mounted) return;
    setState(() {
      _isFirebase = type == LoginType.firebase;
      _uid = userService.value.currentUser?.uid;
    });
  }

  // Add to cart: Firebase accounts save the product and chosen quantity in
  // their Firestore cart (quantity goes up if it is already there).
  // DummyJSON accounts send it to the /carts/add endpoint.
  Future<void> _addToCart() async {
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isFirebase) {
        final uid = _uid;
        if (uid == null) {
          throw AppException('Please log in again to use your cart.');
        }
        await _cartService.addProductToFirebaseCart(
          uid,
          CartProduct(
            id: product.id,
            title: product.title,
            price: product.price,
            quantity: _quantity,
            total: product.price * _quantity,
            discountPercentage: product.discountPercentage,
            discountedTotal: product.price *
                (1 - product.discountPercentage / 100) *
                _quantity,
            thumbnail: product.thumbnail,
          ),
          quantity: _quantity,
        );
      } else {
        await _cartService.addToCart(
          userId: widget.userId,
          products: [
            {'id': product.id, 'quantity': _quantity},
          ],
        );
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Added $_quantity x ${product.title} to cart')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isFirebase ? friendlyError(e) : 'Could not add to cart. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAddToCartBar(BuildContext context) {
    final theme = Theme.of(context);
    final outOfStock = product.stock <= 0;
    final maxQty = product.stock > 0 ? product.stock : 1;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _stepperButton(
              Icons.remove,
              _quantity > 1 ? () => setState(() => _quantity--) : null,
            ),
            SizedBox(width: 10.w),
            CustomText(
              text: '$_quantity',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            SizedBox(width: 10.w),
            _stepperButton(
              Icons.add,
              _quantity < maxQty ? () => setState(() => _quantity++) : null,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: SizedBox(
                height: 44.h,
                child: ElevatedButton.icon(
                  onPressed: (outOfStock || _adding) ? null : _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pinkButton,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    elevation: 0,
                  ),
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart,
                          color: Colors.white),
                  label: Text(
                    outOfStock ? 'Out of stock' : 'Add to Cart',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
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
      bottomNavigationBar: _buildAddToCartBar(context),
      appBar: AppBar(
        title: CustomText(
          text: product.title,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.network(
                  product.thumbnail,
                  height: 250.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image, size: 80),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomText(
                    text: product.title,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8.w),
                CustomText(
                  text: '\$${product.price.toStringAsFixed(2)}',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Chip(
                  label: CustomText(text: product.category, fontSize: 12.sp),
                ),
                SizedBox(width: 8.w),
                if (product.brand.isNotEmpty)
                  Chip(
                    label: CustomText(text: product.brand, fontSize: 12.sp),
                  ),
                const Spacer(),
                const Icon(Icons.star, color: Colors.amber, size: 20),
                SizedBox(width: 4.w),
                CustomText(
                  text: '${product.rating}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            CustomText(
              text: 'Description',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 8.h),
            CustomText(
              text: product.description,
              fontSize: 14.sp,
            ),
            SizedBox(height: 16.h),
            CustomText(
              text: 'Stock: ${product.stock} items available',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }
}