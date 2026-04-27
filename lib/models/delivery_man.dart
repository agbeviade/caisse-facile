class DeliveryMan {
  final int? id;
  final String name;
  final String? phone;

  DeliveryMan({this.id, required this.name, this.phone});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory DeliveryMan.fromMap(Map<String, dynamic> m) => DeliveryMan(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
      );
}
