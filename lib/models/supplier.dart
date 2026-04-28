class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? note;

  Supplier({this.id, required this.name, this.phone, this.note});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
      };

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        note: m['note'] as String?,
      );
}
