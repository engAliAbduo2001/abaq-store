class OrderRequestItem {
  const OrderRequestItem({required this.perfumeId, required this.quantity});

  final String perfumeId;
  final int quantity;

  Map<String, Object> toJson() => {
    'perfumeId': perfumeId,
    'quantity': quantity,
  };
}

class InvoiceCustomer {
  const InvoiceCustomer({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;

  factory InvoiceCustomer.fromJson(Map<String, dynamic> json) {
    return InvoiceCustomer(
      name: _stringField(json, 'name'),
      phone: _stringField(json, 'phone'),
      address: _stringField(json, 'address'),
    );
  }
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.perfumeId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String perfumeId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      perfumeId: _stringField(json, 'perfumeId'),
      name: _stringField(json, 'name'),
      quantity: _intField(json, 'quantity'),
      unitPrice: _numberField(json, 'unitPrice'),
      lineTotal: _numberField(json, 'lineTotal'),
    );
  }
}

class OrderInvoice {
  const OrderInvoice({
    required this.invoiceNumber,
    required this.createdAt,
    required this.customer,
    required this.items,
    required this.paymentMethod,
    required this.subtotal,
    required this.shipping,
    required this.totalAmount,
    required this.currency,
    this.discount = 0,
    this.couponCode,
    this.paymentProvider,
  });

  final String invoiceNumber;
  final DateTime createdAt;
  final InvoiceCustomer customer;
  final List<InvoiceLineItem> items;
  final String paymentMethod;
  final double subtotal;
  final double shipping;
  final double totalAmount;
  final String currency;
  final double discount;
  final String? couponCode;
  final String? paymentProvider;

  factory OrderInvoice.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final rawItems = json['items'];
    final createdAtValue = json['createdAt'];
    if (customer is! Map || rawItems is! List || createdAtValue is! String) {
      throw const FormatException('Invoice record is invalid.');
    }
    final couponCode = json['couponCode'];
    final paymentProvider = json['paymentProvider'];
    if ((couponCode != null && couponCode is! String) ||
        (paymentProvider != null && paymentProvider is! String)) {
      throw const FormatException('Invoice payment details are invalid.');
    }

    return OrderInvoice(
      invoiceNumber: _stringField(json, 'invoiceNumber'),
      createdAt: DateTime.parse(createdAtValue),
      customer: InvoiceCustomer.fromJson(Map<String, dynamic>.from(customer)),
      items: rawItems.map((item) {
        if (item is! Map) {
          throw const FormatException('Invoice item is invalid.');
        }
        return InvoiceLineItem.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
      paymentMethod: _stringField(json, 'paymentMethod'),
      subtotal: _numberField(json, 'subtotal'),
      shipping: _numberField(json, 'shipping'),
      totalAmount: _numberField(json, 'totalAmount'),
      currency: _stringField(json, 'currency'),
      discount: json['discount'] == null
          ? 0
          : _numberField(json, 'discount'),
      couponCode: couponCode as String?,
      paymentProvider: paymentProvider as String?,
    );
  }
}

String _stringField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invoice field "$key" is invalid.');
  }
  return value;
}

double _numberField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('Invoice field "$key" is invalid.');
  }
  return value.toDouble();
}

int _intField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invoice field "$key" is invalid.');
  }
  return value;
}
