import 'package:club_data/club_data.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shopCartProvider =
    StateNotifierProvider<ShopCartNotifier, List<CartItem>>((ref) {
      return ShopCartNotifier();
    });

final shopCartItemCountProvider = Provider<int>((ref) {
  return ref
      .watch(shopCartProvider)
      .fold<int>(0, (sum, item) => sum + item.quantity);
});

final shopCartTotalProvider = Provider<int>((ref) {
  return ref
      .watch(shopCartProvider)
      .fold<int>(0, (sum, item) => sum + item.lineTotal);
});

class ShopCartNotifier extends StateNotifier<List<CartItem>> {
  ShopCartNotifier() : super(const <CartItem>[]);

  void addRawProduct(
    Map<String, dynamic> rawProduct, {
    required String partnerId,
    String fallbackName = '',
    String? selectedVariant,
    int quantity = 1,
  }) {
    final product = _toClubProduct(
      rawProduct,
      partnerId: partnerId,
      fallbackName: fallbackName,
    );
    final maxQuantity = _maxQuantityFor(product);
    if (maxQuantity <= 0) {
      return;
    }
    final index = state.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedVariant == selectedVariant,
    );

    if (index == -1) {
      state = [
        ...state,
        CartItem(
          product: product,
          quantity: quantity.clamp(1, maxQuantity),
          selectedVariant: selectedVariant,
        ),
      ];
      return;
    }

    final updated = [...state];
    final existing = updated[index];
    updated[index] = existing.copyWith(
      quantity: (existing.quantity + quantity).clamp(1, maxQuantity),
    );
    state = updated;
  }

  void increment(CartItem item) {
    _updateQuantity(item, item.quantity + 1);
  }

  void decrement(CartItem item) {
    _updateQuantity(item, item.quantity - 1);
  }

  void remove(CartItem item) {
    state = state
        .where(
          (entry) =>
              entry.product.id != item.product.id ||
              entry.selectedVariant != item.selectedVariant,
        )
        .toList(growable: false);
  }

  void clear() {
    state = const <CartItem>[];
  }

  void _updateQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      remove(item);
      return;
    }

    final maxQuantity = _maxQuantityFor(item.product);
    if (maxQuantity <= 0) {
      remove(item);
      return;
    }

    state = state
        .map((entry) {
          final isSameItem =
              entry.product.id == item.product.id &&
              entry.selectedVariant == item.selectedVariant;
          return isSameItem
              ? entry.copyWith(quantity: quantity.clamp(1, maxQuantity))
              : entry;
        })
        .toList(growable: false);
  }

  int _maxQuantityFor(ClubProduct product) {
    if (product.stock <= 0) {
      return 0;
    }
    return product.stock.clamp(1, 99);
  }

  ClubProduct _toClubProduct(
    Map<String, dynamic> rawProduct, {
    required String partnerId,
    required String fallbackName,
  }) {
    final sizes = switch (rawProduct['available_sizes'] ??
        rawProduct['sizes']) {
      final List<dynamic> values =>
        values.map((value) => value.toString()).toList(),
      final String value when value.trim().isNotEmpty =>
        value.split(',').map((part) => part.trim()).toList(),
      _ => const <String>[],
    };
    final explicitStock =
        (rawProduct['stock'] as num?)?.toInt() ??
        (rawProduct['inventory_count'] as num?)?.toInt();
    final inStock = rawProduct['in_stock'] as bool? ?? true;

    return ClubProduct(
      id: rawProduct['id']?.toString() ?? '',
      partnerId:
          rawProduct['partner_id']?.toString() ??
          rawProduct['club_id']?.toString() ??
          partnerId,
      name: rawProduct['name']?.toString() ?? fallbackName,
      description: rawProduct['description']?.toString() ?? '',
      category: ProductCategoryX.fromValue(rawProduct['category']?.toString()),
      price: (rawProduct['price'] as num?)?.round() ?? 0,
      stock: explicitStock ?? (inStock ? 99 : 0),
      isActive: rawProduct['is_active'] as bool? ?? true,
      isNew: rawProduct['is_new'] as bool? ?? false,
      imageUrl: rawProduct['image_url']?.toString(),
      availableSizes: sizes,
      badgeLabel: rawProduct['badge_label']?.toString(),
      collection: rawProduct['collection']?.toString(),
      sortOrder: (rawProduct['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
