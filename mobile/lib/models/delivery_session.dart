enum SessionStatus { inProgress, completed }

class DeliverySession {
  final int? id;
  final int deliveryManId;
  final SessionStatus status;
  final DateTime startDate;
  final DateTime? endDate;

  DeliverySession({
    this.id,
    required this.deliveryManId,
    required this.status,
    required this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'delivery_man_id': deliveryManId,
        'status': status == SessionStatus.inProgress ? 'IN_PROGRESS' : 'COMPLETED',
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      };

  factory DeliverySession.fromMap(Map<String, dynamic> m) => DeliverySession(
        id: m['id'] as int?,
        deliveryManId: m['delivery_man_id'] as int,
        status: (m['status'] as String) == 'COMPLETED'
            ? SessionStatus.completed
            : SessionStatus.inProgress,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: m['end_date'] != null
            ? DateTime.tryParse(m['end_date'] as String)
            : null,
      );
}

class SessionItem {
  final int sessionId;
  final int productId;
  final double qtyOut;
  final double qtyReturned;
  // Snapshot prices at session time
  final double unitSalePrice;
  final double unitPurchasePrice;

  // Joined fields (not persisted)
  final String? productName;
  final String? productBarcode;

  SessionItem({
    required this.sessionId,
    required this.productId,
    required this.qtyOut,
    this.qtyReturned = 0,
    required this.unitSalePrice,
    required this.unitPurchasePrice,
    this.productName,
    this.productBarcode,
  });

  double get qtySold => qtyOut - qtyReturned;
  double get amountDue => qtySold * unitSalePrice;
  double get profit => qtySold * (unitSalePrice - unitPurchasePrice);

  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'product_id': productId,
        'qty_out': qtyOut,
        'qty_returned': qtyReturned,
        'unit_sale_price': unitSalePrice,
        'unit_purchase_price': unitPurchasePrice,
      };

  factory SessionItem.fromMap(Map<String, dynamic> m) => SessionItem(
        sessionId: m['session_id'] as int,
        productId: m['product_id'] as int,
        qtyOut: (m['qty_out'] as num).toDouble(),
        qtyReturned: (m['qty_returned'] as num?)?.toDouble() ?? 0,
        unitSalePrice: (m['unit_sale_price'] as num).toDouble(),
        unitPurchasePrice: (m['unit_purchase_price'] as num).toDouble(),
        productName: m['name'] as String?,
        productBarcode: m['barcode'] as String?,
      );

  SessionItem copyWith({double? qtyOut, double? qtyReturned}) => SessionItem(
        sessionId: sessionId,
        productId: productId,
        qtyOut: qtyOut ?? this.qtyOut,
        qtyReturned: qtyReturned ?? this.qtyReturned,
        unitSalePrice: unitSalePrice,
        unitPurchasePrice: unitPurchasePrice,
        productName: productName,
        productBarcode: productBarcode,
      );
}
