import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
}
