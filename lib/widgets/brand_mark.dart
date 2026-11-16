import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Logo MotoPart: roda gigi oranye (suku cadang) yang membingkai siluet motor.
///
/// Digambar lewat kode agar tajam di ukuran apa pun dan dipakai bersama oleh
/// aplikasi (`AppLogo`) maupun pembuat ikon (`tool/generate_icons_test.dart`).
class BrandMarkPainter extends CustomPainter {
  /// Menggambar latar charcoal (untuk ikon aplikasi). Tanpa latar, logo
  /// transparan dan cocok di atas permukaan gelap.
  final bool withBackground;

  /// Radius sudut latar, sebagai pecahan dari sisi (0 = penuh tanpa sudut
  /// membulat, mis. untuk iOS/adaptive yang dipotong sistem).
  final double cornerRadius;

  /// Skala isi logo terhadap kanvas (1 = menyentuh tepi, <1 memberi ruang
  /// aman).
  final double contentScale;

  /// Siluet satu warna (hitam, dengan lubang transparan di dial) untuk lapisan
  /// monokrom ikon bertema Android 13+.
  final bool monochrome;

  const BrandMarkPainter({
    this.withBackground = false,
    this.cornerRadius = 0,
    this.contentScale = 1,
    this.monochrome = false,
  });

  static const _white = Color(0xFFF5F5F7);
  static const _mono = Color(0xFF000000);
  static const _dial = Color(0xFF1A1A1D);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    if (withBackground) {
      final rect = Offset.zero & size;
      final background = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.charcoalSoft, AppColors.charcoal],
        ).createShader(rect);
      if (cornerRadius > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(side * cornerRadius)),
          background,
        );
      } else {
        canvas.drawRect(rect, background);
      }
    }

    // Ruang desain 1000 x 1000 dengan titik pusat di tengah.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final k = side * contentScale / 1000;
    canvas.scale(k, k);

    _paintGear(canvas);
    if (!monochrome) _paintDial(canvas);
    _paintMotorcycle(canvas);

    canvas.restore();
  }

  /// Roda gigi 10 gigi, radius luar 470, akar 392.
  void _paintGear(Canvas canvas) {
    const teeth = 10;
    const outer = 470.0;
    const root = 392.0;
    final pitch = 2 * math.pi / teeth;

    final path = Path();
    var first = true;
    for (var i = 0; i < teeth; i++) {
      final a = i * pitch - math.pi / 2;
      // Gigi trapesium: dasar lebih lebar dari puncak.
      final points = <(double, double)>[
        (a - pitch * 0.30, root),
        (a - pitch * 0.17, outer),
        (a + pitch * 0.17, outer),
        (a + pitch * 0.30, root),
      ];
      for (final (angle, radius) in points) {
        final p = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
        if (first) {
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
    }
    path.close();

    if (monochrome) {
      // Roda gigi berlubang di tengah (dial transparan), satu warna.
      final hole = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: 312));
      final ring = Path.combine(PathOperation.difference, path, hole);
      canvas.drawPath(ring, Paint()..color = _mono);
      return;
    }

    final rect = Rect.fromCircle(center: Offset.zero, radius: outer);
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primarySoft, AppColors.primary, Color(0xFFE05500)],
      ).createShader(rect);
    canvas.drawPath(path, fill);

    // Sudut gigi sedikit dibulatkan.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 22
        ..shader = fill.shader,
    );
  }

  /// Panel gelap di tengah roda gigi (seperti dial/tachometer).
  void _paintDial(Canvas canvas) {
    const radius = 312.0;
    canvas.drawCircle(Offset.zero, radius, Paint()..color = _dial);
    // Cincin tipis oranye di tepi dial.
    canvas.drawCircle(
      Offset.zero,
      radius - 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = AppColors.primary.withValues(alpha: 0.55),
    );
  }

  /// Siluet motor tampak samping menghadap kanan (bentuk tebal agar tetap
  /// terbaca di ukuran ikon kecil).
  void _paintMotorcycle(Canvas canvas) {
    // Mode monokrom: semua bagian satu warna.
    final bodyColor = monochrome ? _mono : _white;
    final accentColor = monochrome ? _mono : AppColors.primary;
    final white = Paint()..color = bodyColor;
    final orange = Paint()..color = accentColor;
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = monochrome ? _mono : color;

    // Pusatkan rombongan gambar di dial dan perbesar sedikit.
    canvas.save();
    canvas.translate(0, -34);
    canvas.scale(1.05, 1.05);

    const rear = Offset(-150, 70);
    const front = Offset(150, 70);
    const wheelRadius = 82.0;

    // Lengan ayun dan garpu (di belakang roda).
    canvas.drawLine(rear, const Offset(-44, 76), stroke(_white, 30));
    canvas.drawLine(const Offset(112, -38), front, stroke(_white, 30));

    // Roda: ban putih, pelek gelap di dalamnya, as oranye.
    for (final c in [rear, front]) {
      canvas.drawCircle(c, wheelRadius, stroke(_white, 36));
      canvas.drawCircle(c, 22, orange);
    }

    // Mesin.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-62, 22, 128, 100),
        const Radius.circular(24),
      ),
      orange,
    );

    // Jok + buritan (putih).
    final seat = Path()
      ..moveTo(-222, -22)
      ..quadraticBezierTo(-214, -50, -170, -52)
      ..lineTo(-64, -52)
      ..lineTo(-64, -2)
      ..lineTo(-178, 10)
      ..quadraticBezierTo(-218, 12, -222, -22)
      ..close();
    canvas.drawPath(seat, white);

    // Tangki (oranye) menyambung ke kepala.
    final tank = Path()
      ..moveTo(-54, -78)
      ..lineTo(66, -86)
      ..quadraticBezierTo(116, -84, 126, -36)
      ..lineTo(-54, -36)
      ..close();
    canvas.drawPath(tank, orange);

    // Setang dan lampu depan.
    canvas.drawLine(
      const Offset(88, -96),
      const Offset(152, -110),
      stroke(_white, 26),
    );
    canvas.drawCircle(const Offset(166, -52), 26, white);
    canvas.drawCircle(const Offset(166, -52), 12, orange);

    // Knalpot.
    canvas.drawLine(
      const Offset(52, 124),
      const Offset(-128, 128),
      stroke(_white.withValues(alpha: 0.9), 22),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.withBackground != withBackground ||
      old.cornerRadius != cornerRadius ||
      old.contentScale != contentScale ||
      old.monochrome != monochrome;
}

/// Logo MotoPart sebagai widget berukuran [size] x [size].
class BrandMark extends StatelessWidget {
  final double size;
  final bool withBackground;

  const BrandMark({super.key, required this.size, this.withBackground = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo MotoPart',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: BrandMarkPainter(
          withBackground: withBackground,
          cornerRadius: withBackground ? 0.22 : 0,
        ),
      ),
    );
  }
}
