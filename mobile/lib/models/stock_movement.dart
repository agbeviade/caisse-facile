/// kind: IN (achat, retour client, ajustement+) | OUT (vente, perte, ajustement-)
/// source_type: 'SALE' | 'DELIVERY' | 'EXPENSE' | 'MANUAL'
class StockMovement {
  final int? id;
  final int productId;
  final double qty; // signed: positive for IN, negative for OUT
  final String kind;
  final String? sourceType;
  final int? sourceId;
  final String? note;
  final DateTime date;

  // Joined fields (read-only)
  final String? productName;

  StockMovement({
    this.id,
    required this.productId,
    required this.qty,
    required this.kind,
    this.sourceType,
    this.sourceId,
    this.note,
    required this.date,
    this.productName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'qty': qty,
        'kind': kind,
        'source_type': sourceType,
        'source_id': sourceId,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, dynamic> m) => StockMovement(
        id: m['id'] as int?,
        productId: m['product_id'] as int,
        qty: (m['qty'] as num).toDouble(),
        kind: m['kind'] as String,
        sourceType: m['source_type'] as String?,
        sourceId: m['source_id'] as int?,
        note: m['note'] as String?,
        date: DateTime.parse(m['date'] as String),
        productName: m['product_name'] as String?,
      );
}
