import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/receipt.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/payment_info.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/pages/shared/receipt_page.dart';
import 'package:motopart/store/store.dart';

OrderItem order({
  String status = 'Diproses',
  PaymentInfo? payment,
  List<OrderLine>? lines,
  String? paymentMethod = 'COD',
}) => OrderItem(
  code: 'MP-123',
  customer: 'Siti',
  total: 125000,
  status: status,
  createdAt: DateTime(2026, 11, 18, 9, 5),
  address: 'Siti, 0812, Jl. Mawar 1',
  paymentMethod: paymentMethod,
  payment: payment,
  lines:
      lines ??
      const [
        OrderLine(productId: 1, name: 'Kampas Rem Depan', qty: 2, price: 45000),
        OrderLine(productId: 2, name: 'Filter Oli Honda', qty: 1, price: 25000),
      ],
);

const paid = PaymentInfo(paymentId: 'MP-123', type: 'qris', amount: 125000);

void main() {
  group('Receipt', () {
    test('menghitung subtotal dan ongkir dari total', () {
      final r = Receipt.of(order());
      expect(r.subtotal, 115000);
      expect(r.shipping, 10000);
    });

    test('pesanan tanpa rincian: tanpa subtotal/ongkir', () {
      final r = Receipt.of(order(lines: const []));
      expect(r.subtotal, 0);
      expect(r.shipping, 0);
    });

    test('status bayar: online lunas, COD lunas saat selesai', () {
      expect(Receipt.of(order(payment: paid)).paymentStatus, 'LUNAS');
      expect(Receipt.of(order()).paymentStatus, 'BAYAR DI TEMPAT (COD)');
      expect(Receipt.of(order(status: 'Selesai')).paymentStatus, 'LUNAS');
    });

    test('tersedia kecuali menunggu pembayaran atau dibatalkan', () {
      expect(Receipt.availableFor(order(status: 'Diproses')), isTrue);
      expect(Receipt.availableFor(order(status: 'Dikirim')), isTrue);
      expect(Receipt.availableFor(order(status: 'Selesai')), isTrue);
      expect(
        Receipt.availableFor(order(status: Store.awaitingPaymentStatus)),
        isFalse,
      );
      expect(Receipt.availableFor(order(status: 'Dibatalkan')), isFalse);
    });

    test('teks struk memuat semua rincian penting', () {
      final text = Receipt.of(order()).toText();
      expect(text, contains('MP-123'));
      expect(text, contains('Siti'));
      expect(text, contains('Jl. Mawar 1'));
      expect(text, contains('Kampas Rem Depan'));
      expect(text, contains('2 x Rp 45.000 = Rp 90.000'));
      expect(text, contains('Subtotal    : Rp 115.000'));
      expect(text, contains('Ongkir      : Rp 10.000'));
      expect(text, contains('TOTAL       : Rp 125.000'));
      expect(text, contains('Pembayaran  : COD'));
      expect(text, contains('BAYAR DI TEMPAT (COD)'));
    });
  });

  group('ReceiptPage', () {
    Future<void> show(
      WidgetTester tester,
      OrderItem o, {
      Future<void> Function(String)? onShare,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptPage(order: o, onShare: onShare),
        ),
      );
    }

    testWidgets('menampilkan rincian struk', (tester) async {
      await show(tester, order(payment: paid));

      expect(find.text('STRUK PEMBELIAN'), findsOneWidget);
      expect(find.text('MP-123'), findsOneWidget);
      expect(find.text('Kampas Rem Depan'), findsOneWidget);
      expect(find.text('2 x Rp 45.000'), findsOneWidget);
      expect(find.text('Rp 115.000'), findsOneWidget);
      expect(find.text('Rp 10.000'), findsOneWidget);
      expect(find.text('Rp 125.000'), findsOneWidget);
      expect(find.byKey(const ValueKey('receipt-status')), findsOneWidget);
      expect(find.text('LUNAS'), findsOneWidget);
    });

    testWidgets('Bagikan Struk mengirim teks struk', (tester) async {
      String? shared;
      await show(tester, order(), onShare: (t) async => shared = t);

      await tester.tap(find.text('Bagikan Struk'));
      await tester.pump();

      expect(shared, contains('MP-123'));
      expect(shared, contains('TOTAL       : Rp 125.000'));
    });

    testWidgets('berbagi gagal: struk disalin ke papan klip', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await show(tester, order(), onShare: (_) async => throw Exception('x'));

      await tester.tap(find.text('Bagikan Struk'));
      await tester.pump();

      expect(clipboard, contains('MP-123'));
      expect(find.textContaining('disalin'), findsOneWidget);
    });

    testWidgets('Salin Struk menyalin teks', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await show(tester, order());

      await tester.tap(find.text('Salin Struk'));
      await tester.pump();

      expect(clipboard, contains('Kampas Rem Depan'));
      expect(find.text('Struk disalin.'), findsOneWidget);
    });

    testWidgets('tanpa rincian barang: pesan dan total saja', (tester) async {
      await show(tester, order(lines: const []));

      expect(
        find.text('Rincian barang tidak tersedia untuk pesanan ini.'),
        findsOneWidget,
      );
      expect(find.text('Rp 125.000'), findsOneWidget);
    });
  });

  group('Tombol Lihat Struk di detail pesanan', () {
    Future<void> show(WidgetTester tester, OrderItem o) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: OrderDetailPage(order: o)));
    }

    testWidgets('ada untuk pesanan diproses dan membuka struk', (tester) async {
      await show(tester, order());

      await tester.tap(find.text('Lihat Struk'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptPage), findsOneWidget);
    });

    testWidgets('tidak ada untuk menunggu pembayaran atau dibatalkan', (
      tester,
    ) async {
      await show(tester, order(status: Store.awaitingPaymentStatus));
      expect(find.text('Lihat Struk'), findsNothing);

      await show(tester, order(status: 'Dibatalkan'));
      await tester.pump();
      expect(find.text('Lihat Struk'), findsNothing);
    });
  });
}
