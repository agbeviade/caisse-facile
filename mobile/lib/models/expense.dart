class Expense {
  final int? id;
  final DateTime date;
  final double amount;
  final String? category;
  final int? supplierId;
  final String? note;

  Expense({
    this.id,
    required this.date,
    required this.amount,
    this.category,
    this.supplierId,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'category': category,
        'supplier_id': supplierId,
        'note': note,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int?,
        date: DateTime.parse(m['date'] as String),
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String?,
        supplierId: m['supplier_id'] as int?,
        note: m['note'] as String?,
      );
}
