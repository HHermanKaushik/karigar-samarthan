import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';

final ordersProvider = Provider<List<CustomerOrder>>((ref) {
  final now = DateTime.now();
  return [
    CustomerOrder(
      id: '003',
      productTitle: 'Handwoven Pashmina Shawl',
      quantity: 1,
      total: 3500,
      placedAt: now,
      status: OrderStatus.placed,
      customerName: 'Mr. Ravi Kumar',
      shippingAddress:
          'No. 45, 5th Cross, Indiranagar\nBengaluru, Karnataka - 560038',
      customerPhone: '+91 9876543210',
    ),
    CustomerOrder(
      id: '002',
      productTitle: 'Jamawar Silk Saree',
      quantity: 1,
      total: 8900,
      placedAt: now.subtract(const Duration(days: 1)),
      status: OrderStatus.shipped,
      customerName: 'Ms. Priya Sharma',
      shippingAddress: 'Flat 12B, Sea View, Bandra West\nMumbai - 400050',
      customerPhone: '+91 9123456780',
    ),
    CustomerOrder(
      id: '001',
      productTitle: 'Bokhara wool-silk rug',
      quantity: 1,
      total: 12500,
      placedAt: now.subtract(const Duration(days: 5)),
      status: OrderStatus.paid,
      customerName: 'Mr. Aarav Singh',
      shippingAddress: 'House 7, Sector 21\nGurugram, Haryana - 122016',
      customerPhone: '+91 9988776655',
    ),
  ];
});
