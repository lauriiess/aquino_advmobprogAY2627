import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/cart.dart';

class CartService {
  /// dummyjson occasionally resets the connection (errno 104). Use a fresh
  /// client per attempt (no stale keep-alive socket) and retry with backoff.
  Future<http.Response> _send(
    Future<http.Response> Function(http.Client client) request, {
    int maxAttempts = 4,
  }) async {
    for (var attempt = 1;; attempt++) {
      final client = http.Client();
      try {
        return await request(client).timeout(const Duration(seconds: 15));
      } catch (e) {
        final retryable = e is http.ClientException ||
            e is SocketException ||
            e is TimeoutException;
        if (!retryable || attempt >= maxAttempts) rethrow;
      } finally {
        client.close();
      }
      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }
  }

  // ---------------------------------------------------------------------
  // DummyJSON (read-only cart)
  // ---------------------------------------------------------------------

  Future<List<Cart>> getAllCarts() async {
    final response = await _send((c) => c.get(Uri.parse("$host/carts")));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List cartsJson = data['carts'] ?? [];
      return cartsJson.map((json) => Cart.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load carts');
    }
  }

  // Enhancement 3: this only grabs the cart for one user (using
  // /carts/user/{id}) instead of pulling every cart in the system
  Future<Cart?> getCartByUserId(int userId) async {
    final response = await _send(
      (c) => c.get(Uri.parse('$host/carts/user/$userId')),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List cartsJson = data['carts'] ?? [];
      if (cartsJson.isNotEmpty) {
        return Cart.fromJson(cartsJson.first);
      }
      return null;
    } else {
      throw Exception('Failed to load user cart');
    }
  }

  // Enhancement 3: tried out the /carts/add endpoint too -- send a userId
  // plus a list of {id, quantity} and it hands back the updated cart
  Future<Cart> addToCart({
    required int userId,
    required List<Map<String, dynamic>> products,
  }) async {
    final response = await _send(
      (c) => c.post(
        Uri.parse('$host/carts/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'products': products,
        }),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Cart.fromJson(data);
    } else {
      throw Exception('Failed to add product to cart');
    }
  }

  // ---------------------------------------------------------------------
  // Products (DummyJSON catalog, used to pick what to add to a Firebase cart)
  // ---------------------------------------------------------------------

  /// lists products, or searches them when [query] is not empty.
  /// quantity is 1 so the result can be added to a cart as is.
  Future<List<CartProduct>> getProducts({String query = ''}) async {
    const fields = 'id,title,price,discountPercentage,thumbnail';
    final q = query.trim();
    final uri = q.isEmpty
        ? Uri.parse('$host/products?limit=30&select=$fields')
        : Uri.parse(
            '$host/products/search?q=${Uri.encodeQueryComponent(q)}&limit=30&select=$fields');

    final response = await _send((c) => c.get(uri));
    if (response.statusCode != 200) {
      throw Exception('Failed to load products');
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    final List list = data['products'] ?? [];
    return list.map((json) {
      final p = CartProduct.fromJson(json);
      return CartProduct(
        id: p.id,
        title: p.title,
        price: p.price,
        quantity: 1,
        total: p.price,
        discountPercentage: p.discountPercentage,
        discountedTotal: p.price * (1 - p.discountPercentage / 100),
        thumbnail: p.thumbnail,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Firebase carts (saved in Firestore: Users/{uid}/cart/{productId})
  // ---------------------------------------------------------------------

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cartRef(String uid) =>
      _db.collection('Users').doc(uid).collection('cart');

  /// live cart of one Firebase user, built into the same Cart model the
  /// DummyJSON cart uses so the screens can share the same widgets
  Stream<Cart> watchFirebaseCart(String uid) {
    return _cartRef(uid).snapshots().map((snap) {
      final products = snap.docs.map((d) {
        final m = d.data();
        final price = (m['price'] as num?)?.toDouble() ?? 0.0;
        final discount = (m['discountPercentage'] as num?)?.toDouble() ?? 0.0;
        final qty = (m['quantity'] as num?)?.toInt() ?? 1;
        final total = price * qty;
        return CartProduct(
          id: (m['id'] as num?)?.toInt() ?? 0,
          title: (m['title'] ?? '').toString(),
          price: price,
          quantity: qty,
          total: total,
          discountPercentage: discount,
          discountedTotal: total * (1 - discount / 100),
          thumbnail: (m['thumbnail'] ?? '').toString(),
        );
      }).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

      final total = products.fold<double>(0, (s, p) => s + p.total);
      final discounted = products.fold<double>(0, (s, p) => s + p.discountedTotal);
      final quantity = products.fold<int>(0, (s, p) => s + p.quantity);

      return Cart(
        id: 0,
        products: products,
        total: total,
        discountedTotal: discounted,
        userId: 0,
        totalProducts: products.length,
        totalQuantity: quantity,
      );
    });
  }

  /// adds a product, or raises its quantity if it is already in the cart
  Future<void> addProductToFirebaseCart(
    String uid,
    CartProduct product, {
    int quantity = 1,
  }) {
    return _cartRef(uid).doc(product.id.toString()).set({
      'id': product.id,
      'title': product.title,
      'price': product.price,
      'discountPercentage': product.discountPercentage,
      'thumbnail': product.thumbnail,
      'quantity': FieldValue.increment(quantity),
    }, SetOptions(merge: true));
  }

  Future<void> setFirebaseQuantity(String uid, int productId, int quantity) {
    if (quantity < 1) return removeFromFirebaseCart(uid, productId);
    return _cartRef(uid).doc(productId.toString()).update({
      'quantity': quantity,
    });
  }

  Future<void> removeFromFirebaseCart(String uid, int productId) {
    return _cartRef(uid).doc(productId.toString()).delete();
  }

  /// saves the cart as an order under Users/{uid}/orders, then empties the cart
  Future<void> checkoutFirebaseCart(String uid, Cart cart) async {
    final orderRef = _db.collection('Users').doc(uid).collection('orders').doc();
    final batch = _db.batch();

    batch.set(orderRef, {
      'items': cart.products.map((p) => p.toJson()).toList(),
      'total': cart.total,
      'discountedTotal': cart.discountedTotal,
      'totalQuantity': cart.totalQuantity,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final p in cart.products) {
      batch.delete(_cartRef(uid).doc(p.id.toString()));
    }
    await batch.commit();
  }
}