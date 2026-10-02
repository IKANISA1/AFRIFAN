import 'dart:convert';

import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';

/// A product in the club shop.
class ClubProduct extends Equatable {
  /// Public Data API projection. Rights-review actors, generation prompts and
  /// provenance records intentionally remain server-side.
  static const String dataApiProjection =
      'id, partner_id, name, description, category, price, stock, '
      'is_active, is_new, image_url, available_sizes, badge_label, '
      'collection, sort_order, image_rights_approved, image_provenance_id';

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
    this.imageRightsApproved = false,
    this.imageProvenanceId,
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
  final bool imageRightsApproved;
  final String? imageProvenanceId;
  final List<String> availableSizes;
  final String? badgeLabel;
  final String? collection;
  final int sortOrder;

  int discountedPrice(double discountPct) {
    final normalized = discountPct.clamp(0, 100);
    return (price * (1 - normalized / 100)).round();
  }

  factory ClubProduct.fromJson(Map<String, dynamic> json) {
    final rawSizes = switch (json['available_sizes'] ?? json['sizes']) {
      final List<dynamic> values => values,
      final String value when value.trim().isNotEmpty =>
        value
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(),
      _ => const <dynamic>[],
    };

    return ClubProduct(
      id: jh.asStringOrNull(json['id']) ?? '',
      partnerId:
          jh.asStringOrNull(json['partner_id']) ??
          jh.asStringOrNull(json['club_id']) ??
          '',
      name: jh.asStringOrNull(json['name']) ?? 'Shop Item',
      description: jh.asStringOrNull(json['description']) ?? '',
      category: jh.ProductCategoryX.fromValue(json['category']?.toString()),
      price: jh.asInt(json['price']),
      stock: jh.asInt(json['stock'], fallback: 99),
      isActive: jh.asBool(json['is_active'], fallback: true),
      isNew: jh.asBool(json['is_new']),
      imageUrl: jh.asStringOrNull(json['image_url']),
      imageRightsApproved: jh.asBool(json['image_rights_approved']),
      imageProvenanceId: jh.asStringOrNull(json['image_provenance_id']),
      availableSizes: rawSizes
          .map((size) => size.toString().trim())
          .where((size) => size.isNotEmpty)
          .toList(growable: false),
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
    'image_rights_approved': imageRightsApproved,
    'image_provenance_id': imageProvenanceId,
    'sizes': availableSizes,
    'badge_label': badgeLabel,
    'collection': collection,
    'sort_order': sortOrder,
  };

  @override
  List<Object?> get props => [
    id,
    partnerId,
    name,
    category,
    price,
    stock,
    imageUrl,
    imageRightsApproved,
    imageProvenanceId,
  ];
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
    this.updatedAt,
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
  final DateTime? updatedAt;

  factory ClubShopOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final productJson = item['product'] as Map<String, dynamic>? ?? item;
          return CartItem(
            product: ClubProduct.fromJson(productJson),
            quantity: jh.asInt(item['quantity'], fallback: 1).clamp(1, 9999),
            selectedVariant: jh.asStringOrNull(item['selected_variant']),
          );
        })
        .toList(growable: false);

    final subtotal = jh.asInt(json['subtotal']);
    final discount = jh.asInt(json['discount_amount']);
    final delivery = jh.asInt(json['delivery_fee']);

    return ClubShopOrder(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      partnerId:
          jh.asStringOrNull(json['partner_id']) ??
          jh.asStringOrNull(json['club_id']),
      items: List.unmodifiable(items),
      subtotal: subtotal,
      discountAmount: discount,
      deliveryFee: delivery,
      total: jh.asInt(json['total'], fallback: subtotal - discount + delivery),
      deliveryAddress: jh.asStringOrNull(json['delivery_address']) ?? '',
      paymentReference: jh.asStringOrNull(json['momo_reference']) ?? '',
      status: jh.OrderStatusX.fromValue(json['status']?.toString()),
      createdAt: jh.parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: jh.parseDateTime(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [id, userId, status, total, createdAt, updatedAt];
}

/// One frozen server order and payment instruction. A pending receipt is not a
/// payment acknowledgement. [canPay] is refreshed by the server before handoff.
class ShopCheckoutReceipt extends Equatable {
  const ShopCheckoutReceipt._({
    required this.order,
    required this.clubId,
    required this.currency,
    required this.recipientCode,
    required this.country,
    required this.provider,
    required this.ussdCode,
    required this.expiresAt,
    required this.serverStatus,
    required this.canPay,
    required String frozen,
  }) : _frozen = frozen;

  final ClubShopOrder order;
  final int clubId;
  final String currency, recipientCode, country, provider, ussdCode;
  final DateTime expiresAt;
  final String serverStatus;
  final bool canPay;
  final String _frozen;
  String get id => order.id;
  int get total => order.total;
  String get userId => order.userId;
  String get paymentReference => order.paymentReference;
  bool get pending => serverStatus == 'pending';
  bool get terminal => !pending;
  Map<String, dynamic> get frozen =>
      jsonDecode(_frozen) as Map<String, dynamic>;

  bool sameInstruction(ShopCheckoutReceipt other) => _frozen == other._frozen;

  static String _canonical(Object? value) => jsonEncode(_sorted(value));
  static Object? _sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _sorted(value[key])};
    }
    if (value is List) return value.map(_sorted).toList(growable: false);
    return value;
  }

  factory ShopCheckoutReceipt.fromJson(Map<String, dynamic> response) {
    void require(bool valid) {
      if (!valid) throw const FormatException('SHOP_RECEIPT_INVALID');
    }

    final row = response['order'];
    final receipt = response['receipt'];
    require(row is Map<String, dynamic> && receipt is Map<String, dynamic>);
    final data = row as Map<String, dynamic>;
    final facts = receipt as Map<String, dynamic>;
    final idPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    require(facts['version'] == 1 && response['can_pay'] is bool);
    require(
      idPattern.hasMatch('${data['id']}') &&
          idPattern.hasMatch('${data['user_id']}'),
    );
    require(data['club_id'] is int && (data['club_id'] as int) > 0);
    for (final key in [
      'id',
      'user_id',
      'club_id',
      'total',
      'delivery_address',
    ]) {
      require(data[key] == facts[key == 'id' ? 'order_id' : key]);
    }
    require(data['momo_reference'] == facts['payment_reference']);
    require(data['reservation_expires_at'] == facts['expires_at']);
    require(_canonical(data['items']) == _canonical(facts['items']));
    require(
      RegExp(
        r'^order-[0-9a-f-]{36}$',
      ).hasMatch('${facts['payment_reference']}'),
    );
    require(
      facts['currency'] is String &&
          RegExp(r'^[A-Z]{3}$').hasMatch(facts['currency'] as String),
    );
    require(
      facts['country'] is String &&
          RegExp(r'^[A-Z]{2}$').hasMatch(facts['country'] as String),
    );
    require(
      facts['recipient_code'] is String &&
          RegExp(r'^[0-9]{1,40}$').hasMatch(facts['recipient_code'] as String),
    );
    require(
      facts['provider'] is String &&
          RegExp(r'^[a-z0-9_ -]{1,80}$').hasMatch(facts['provider'] as String),
    );
    require(
      idPattern.hasMatch('${facts['receiver_id']}') &&
          idPattern.hasMatch('${facts['route_id']}'),
    );
    require(
      facts['ussd_code'] is String &&
          RegExp(r'^\*[0-9*]+#$').hasMatch(facts['ussd_code'] as String),
    );
    require(
      data['items'] is List &&
          (data['items'] as List).isNotEmpty &&
          (data['items'] as List).length <= 20,
    );
    var subtotal = 0;
    for (final value in data['items'] as List) {
      require(value is Map<String, dynamic>);
      final item = value as Map<String, dynamic>;
      final product = item['product'];
      require(product is Map<String, dynamic> && item['quantity'] is int);
      final fields = product as Map<String, dynamic>;
      require(
        fields['id'] == item['product_id'] &&
            idPattern.hasMatch('${fields['id']}'),
      );
      require(fields['price'] is int && (fields['price'] as int) >= 0);
      require(
        (item['quantity'] as int) >= 1 && (item['quantity'] as int) <= 20,
      );
      require(fields['club_id'] == data['club_id']);
      subtotal += (fields['price'] as int) * (item['quantity'] as int);
    }
    require(
      data['subtotal'] == subtotal &&
          data['discount_amount'] is int &&
          (data['discount_amount'] as int) >= 0 &&
          data['delivery_fee'] is int &&
          (data['delivery_fee'] as int) >= 0,
    );
    require(
      data['total'] is int &&
          (data['total'] as int) > 0 &&
          (data['total'] as int) <= 2147483647,
    );
    require(
      data['total'] ==
          subtotal -
              (data['discount_amount'] as int) +
              (data['delivery_fee'] as int),
    );
    require(
      const {
        'pending',
        'paid',
        'confirmed',
        'packed',
        'shipped',
        'fulfilled',
        'delivered',
        'cancelled',
      }.contains(data['status']),
    );
    final expiry = DateTime.tryParse('${facts['expires_at']}');
    require(
      expiry != null && DateTime.tryParse('${data['created_at']}') != null,
    );
    return ShopCheckoutReceipt._(
      order: ClubShopOrder.fromJson(data),
      clubId: data['club_id'] as int,
      currency: facts['currency'] as String,
      recipientCode: facts['recipient_code'] as String,
      country: facts['country'] as String,
      provider: facts['provider'] as String,
      ussdCode: facts['ussd_code'] as String,
      expiresAt: expiry!,
      serverStatus: data['status'] as String,
      canPay: response['can_pay'] as bool,
      frozen: _canonical(facts),
    );
  }

  @override
  List<Object?> get props => [_frozen, serverStatus, canPay];
}
