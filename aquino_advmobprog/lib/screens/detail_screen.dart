import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/cart.dart';
import '../widgets/custom_text.dart';

// Enhancement 1: this is the screen you land on when you tap a cart item.
// It shows the picture, price, discount, and a quick order summary for that one product.
class DetailScreen extends StatelessWidget {
  final CartProduct product;

  const DetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  height: 220.h,
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
                  label: CustomText(
                    text:
                        '${product.discountPercentage.toStringAsFixed(1)}% OFF',
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                CustomText(
                  text: 'Quantity: ${product.quantity}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
            SizedBox(height: 24.h),
            CustomText(
              text: 'Order Summary',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText(
                  text: 'Subtotal (${product.quantity} items):',
                  fontSize: 14.sp,
                ),
                CustomText(
                  text: '\$${product.total.toStringAsFixed(2)}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomText(
                  text: 'Discounted Subtotal:',
                  fontSize: 14.sp,
                ),
                CustomText(
                  text: '\$${product.discountedTotal.toStringAsFixed(2)}',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
