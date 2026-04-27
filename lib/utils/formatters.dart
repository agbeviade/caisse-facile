import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'F',
  decimalDigits: 0,
);

String fmtMoney(num v) => _money.format(v);
String fmtQty(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String fmtDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
