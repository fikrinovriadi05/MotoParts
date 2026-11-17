import 'package:flutter/material.dart';
import 'package:motopart/pages/auth/splash_page.dart';
import 'package:motopart/store/remote_sync.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';

/// Untuk menampilkan pesan dari luar pohon halaman (mis. galat sinkronisasi).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MotoPartApp extends StatelessWidget {
  /// Lebar maksimum isi aplikasi. Di layar yang lebih lebar (desktop/web) isi
  /// berada di tengah dengan latar yang sama di kiri-kanan, agar tidak
  /// terentang sampai tepi layar.
  static const maxContentWidth = 1100.0;

  const MotoPartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController.changes,
      builder: (context, _) {
        final mode = themeController.value;
        final accent = themeController.accent.value;
        return MaterialApp(
          scaffoldMessengerKey: rootMessengerKey,
          title: 'MotoPart',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(accent: accent),
          darkTheme: AppTheme.dark(accent: accent),
          themeMode: mode,
          // Pergantian tema (mode/warna) berubah halus.
          themeAnimationDuration: UiConfig.motion(
            const Duration(milliseconds: 350),
          ),
          themeAnimationCurve: Curves.easeInOut,
          builder: (context, child) =>
              _SyncErrorListener(child: _WideFrame(child: child!)),
          home: const SplashPage(),
        );
      },
    );
  }
}

/// Di layar yang lebih lebar dari [MotoPartApp.maxContentWidth], isi aplikasi
/// berada di tengah sebagai "bingkai" dengan latar luar yang berbeda dan
/// bayangan tepi (bukan terentang sampai tepi layar). Di layar yang lebih
/// sempit anaknya dipakai apa adanya.
class _WideFrame extends StatelessWidget {
  final Widget child;

  const _WideFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const width = MotoPartApp.maxContentWidth;
        if (constraints.maxWidth <= width) return child;

        final dark = Theme.of(context).brightness == Brightness.dark;
        final media = MediaQuery.of(context);
        return ColoredBox(
          color: dark ? const Color(0xFF0E0E10) : const Color(0xFFE2E2E7),
          child: Center(
            child: SizedBox(
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.5 : 0.18),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: ClipRect(
                  // Ukuran layar di dalam bingkai = lebar bingkai.
                  child: MediaQuery(
                    data: media.copyWith(size: Size(width, media.size.height)),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Menampilkan galat pengiriman data ke server sebagai snackbar.
class _SyncErrorListener extends StatefulWidget {
  final Widget child;

  const _SyncErrorListener({required this.child});

  @override
  State<_SyncErrorListener> createState() => _SyncErrorListenerState();
}

class _SyncErrorListenerState extends State<_SyncErrorListener> {
  @override
  void initState() {
    super.initState();
    RemoteSync.error.addListener(_show);
  }

  @override
  void dispose() {
    RemoteSync.error.removeListener(_show);
    super.dispose();
  }

  void _show() {
    final message = RemoteSync.error.value;
    if (message == null) return;
    RemoteSync.error.value = null;
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
