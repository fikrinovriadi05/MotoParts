import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/app.dart';
import 'package:motopart/pages/auth/onboarding_page.dart';
import 'package:motopart/pages/auth/splash_page.dart';

void main() {
  testWidgets('MotoPart app berjalan dengan baik',
      (WidgetTester tester) async {
    
    // Menjalankan aplikasi MotoPart
    await tester.pumpWidget(const MotoPartApp());

    // Memastikan halaman splash muncul
    expect(find.byType(SplashPage), findsOneWidget);

    // Menunggu perpindahan ke halaman onboarding
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Memastikan halaman onboarding muncul
    expect(find.byType(OnboardingPage), findsOneWidget);
  });
}
