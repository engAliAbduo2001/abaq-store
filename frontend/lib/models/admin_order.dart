import 'order_invoice.dart';

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.status,
    required this.invoice,
  });

  final String id;
  final String status;
  final OrderInvoice invoice;

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    if (id is! String || id.isEmpty || status is! String || status.isEmpty) {
      throw const FormatException('Admin order record is invalid.');
    }
    return AdminOrder(
      id: id,
      status: status,
      invoice: OrderInvoice.fromJson(json),
    );
  }
}
