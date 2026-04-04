import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';

/// A product in the club shop.
class ClubProduct extends Equatable {
  const ClubProduct({
    required this.id,
    required this.partnerId,
    required this.name,
    this.description = '',
    required this.category,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.isNew,
    this.imageUrl,
    this.availableSizes = const <String>[],
    this.badgeLabel,
    this.collection,
    this.sortOrder = 0,
  });

  final String id;
  final String partnerId;
  final String name;
  final String description;
  final jh.ProductCategory category;
  final int price;
  final int stock;
  final bool isActive;
  final bool isNew;
  final String? imageUrl;
  final List<String> availableSizes;
  final String? badgeLabel;
  final String? collection;
  final int sortOrder;

  int discountedPrice(double discountPct) {
    final normalized = discountPct.clamp(0, 100);
    return (price * (1 - normalized / 100)).round();
  }

  factory ClubProduct.fromJson(Map<String, dynamic> json) {
    return ClubProduct(
      id: jh.asStringOrNull(json['id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']) ?? '',
      name: jh.asStringOrNull(json['name']) ?? 'Shop Item',
      description: jh.asStringOrNull(json['description']) ?? '',
      category: jh.ProductCategoryX.fromValue(json['category']?.toString()),
      price: jh.asInt(json['price']),
      stock: jh.asInt(json['stock'], fallback: 99),
      isActive: jh.asBool(json['is_active'], fallback: true),
      isNew: jh.asBool(json['is_new']),
      imageUrl: jh.asStringOrNull(json['image_url']),
      availableSizes: (json['sizes'] as List?)
              ?.map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      badgeLabel: jh.asStringOrNull(json['badge_label']),
      collection: jh.asStringOrNull(json['collection']),
      sortOrder: jh.asInt(json['sort_order']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partner_id': partnerId,
        'name': name,
        'description': description,
        'category': category.value,
        'price': price,
        'stock': stock,
        'is_active': isActive,
        'is_new': isNew,
        'image_url': imageUrl,
        'sizes': availableSizes,
        'badge_label': badgeLabel,
        'collection': collection,
        'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [id, partnerId, name, category, price, stock];
}

/// A single item in the shopping cart.
class CartItem extends Equatable {
  const CartItem({
    required this.product,
    required this.quantity,
    this.selectedVariant,
  });

  final ClubProduct product;
  final int quantity;
  final String? selectedVariant;

  int get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity, String? selectedVariant}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      selectedVariant: selectedVariant ?? this.selectedVariant,
    );
  }

  @override
  List<Object?> get props => [product, quantity, selectedVariant];
}

/// A completed shop order.
class ClubShopOrder extends Equatable {
  const ClubShopOrder({
    required this.id,
    required this.userId,
    this.partnerId,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.total,
    required this.deliveryAddress,
    required this.paymentReference,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? partnerId;
  final List<CartItem> items;
  final int subtotal;
  final int discountAmount;
  final int deliveryFee;
  final int total;
  final String deliveryAddress;
  final String paymentReference;
  final jh.OrderStatus status;
  final DateTime createdAt;

  factory ClubShopOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final items = rawItems.whereType<Map<String, dynamic>>().map((item) {
      final productJson = item['product'] as Map<String, dynamic>? ?? item;
      return CartItem(
        product: ClubProduct.fromJson(productJson),
        quantity: jh.asInt(item['quantity'], fallback: 1).clamp(1, 9999),
        selectedVariant: jh.asStringOrNull(item['selected_variant']),
      );
    }).toList(growable: false);

    final subtotal = jh.asInt(json['subtotal']);
    final discount = jh.asInt(json['discount_amount']);
    final delivery = jh.asInt(json['delivery_fee']);

    return ClubShopOrder(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']),
      items: items,
      subtotal: subtotal,
      discountAmount: discount,
      deliveryFee: delivery,
      total: jh.asInt(json['total'], fallback: subtotal - discount + delivery),
      deliveryAddress: jh.asStringOrNull(json['delivery_address']) ?? '',
      paymentReference: jh.asStringOrNull(json['momo_reference']) ?? '',
      status: jh.OrderStatusX.fromValue(json['status']?.toString()),
      createdAt: jh.parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, userId, status, total, createdAt];
}
