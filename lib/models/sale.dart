class Sale {
  final int? id;
  final DateTime date;
  final double total;
  final double profit;

  Sale({this.id, required this.date, required this.total, required this.profit});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'total': total,
        'profit': profit,
      };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        total: (m['total'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
      );
}

class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final double qty;
  final double unitSalePrice;
  final double unitPurchasePrice;
  final String? productName;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.qty,
    required this.unitSalePrice,
    required this.unitPurchasePrice,
    this.productName,
  });

  double get total => qty * unitSalePrice;
  double get profit => qty * (unitSalePrice - unitPurchasePrice);

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'qty': qty,
        'unit_sale_price': unitSalePrice,
        'unit_purchase_price': unitPurchasePrice,
      };
}
