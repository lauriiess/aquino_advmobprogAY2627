import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/product.dart';

class ProductService {
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

  Future<List<Product>> getAllProducts() async {
    final response = await _send((c) => c.get(Uri.parse('$host/products')));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List productsJson = data['products'] ?? [];
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }
}