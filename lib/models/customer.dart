class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? note;
  final double balance; // positive = customer owes shop

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.note,
    this.balance = 0,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? note,
    double? balance,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        note: note ?? this.note,
        balance: balance ?? this.balance,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'balance': balance,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        note: m['note'] as String?,
        balance: (m['balance'] as num?)?.toDouble() ?? 0,
      );
}

class CustomerCredit {
  final int? id;
  final int customerId;
  final int? saleId;
  final double amount; // positive = credit (sale on credit), negative not used (use kind)
  final String kind; // 'CREDIT' (vente à crédit) or 'PAYMENT' (remboursement)
  final String? note;
  final DateTime date;

  CustomerCredit({
    this.id,
    required this.customerId,
    this.saleId,
    required this.amount,
    required this.kind,
    this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'sale_id': saleId,
        'amount': amount,
        'kind': kind,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory CustomerCredit.fromMap(Map<String, dynamic> m) => CustomerCredit(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        saleId: m['sale_id'] as int?,
        amount: (m['amount'] as num).toDouble(),
        kind: m['kind'] as String,
        note: m['note'] as String?,
        date: DateTime.parse(m['date'] as String),
      );

  /// Signed delta to balance: CREDIT increases what customer owes, PAYMENT decreases it.
  double get balanceDelta => kind == 'PAYMENT' ? -amount.abs() : amount.abs();
}
