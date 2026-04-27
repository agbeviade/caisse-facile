class Product {
  final int? id;
  final String barcode;
  final String name;
  final String? category;
  final double purchasePrice;
  final double salePrice;
  final double stockQty;
  final double alertThreshold;
  final DateTime? expiryDate;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.category,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockQty,
    this.alertThreshold = 0,
    this.expiryDate,
  });

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? category,
    double? purchasePrice,
    double? salePrice,
    double? stockQty,
    double? alertThreshold,
    DateTime? expiryDate,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      stockQty: stockQty ?? this.stockQty,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'category': category,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'stock_qty': stockQty,
        'alert_threshold': alertThreshold,
        'expiry_date': expiryDate?.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int?,
        barcode: m['barcode'] as String,
        name: m['name'] as String,
        category: m['category'] as String?,
        purchasePrice: (m['purchase_price'] as num).toDouble(),
        salePrice: (m['sale_price'] as num).toDouble(),
        stockQty: (m['stock_qty'] as num).toDouble(),
        alertThreshold: (m['alert_threshold'] as num?)?.toDouble() ?? 0,
        expiryDate: m['expiry_date'] != null
            ? DateTime.tryParse(m['expiry_date'] as String)
            : null,
      );
}
