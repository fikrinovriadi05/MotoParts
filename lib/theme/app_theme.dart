import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pengaturan perilaku UI yang bisa dimatikan di tes.
class UiConfig {
  /// Memakai Poppins/Montserrat dari google_fonts (diunduh saat pertama
  /// dipakai, lalu di-cache). Dimatikan di tes agar tidak mengakses jaringan.
  static bool useGoogleFonts = true;

  /// Menampilkan efek shimmer sesaat sebelum produk tampil.
  static bool simulateLoading = true;

  static Duration get loadingDuration =>
      simulateLoading ? const Duration(milliseconds: 650) : Duration.zero;
}

/// Warna merek & status. Sama di mode terang maupun gelap.
/// Warna yang berubah menurut mode ada di [AppPalette] (`context.palette`).
class AppColors {
  /// Oranye racing.
  static const Color primary = Color(0xFFFF6B00);
  static const Color primarySoft = Color(0xFFFF8A3D);

  /// Charcoal: dasar mode gelap dan latar header/gradien di kedua mode.
  static const Color charcoal = Color(0xFF1A1A1D);
  static const Color charcoalSoft = Color(0xFF26262B);

  /// Teks/ikon di atas warna [primary]. Gelap, karena putih di atas oranye
  /// kontrasnya rendah (sekitar 2,9:1).
  static const Color onPrimary = charcoal;

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFEF4444);
  static const Color star = Color(0xFFFFB400);
}

class AppRadius {
  static const double sm = 10;
  static const double md = 12;

  /// Kartu, input, dan tombol.
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Jarak tepi halaman.
  static const double page = 18;
}

class AppSizes {
  /// Area sentuh minimal.
  static const double minTap = 48;
  static const double buttonHeight = 54;
  static const double navBarHeight = 72;
}

class AppTextSizes {
  static const double caption = 11;
  static const double small = 12;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double title = 18;
  static const double heading = 24;
  static const double display = 28;
}

/// Warna yang mengikuti mode terang/gelap. Ambil lewat `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;

  /// Oranye untuk teks/ikon kecil: lebih gelap di mode terang agar kontras.
  final Color primaryText;
  final Color shadow;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primaryText,
    required this.shadow,
  });

  static const dark = AppPalette(
    bg: AppColors.charcoal,
    surface: Color(0xFF232327),
    surfaceAlt: Color(0xFF2C2C31),
    border: Color(0xFF34343A),
    text: Color(0xFFF5F5F7),
    textMuted: Color(0xFFA1A1AA),
    primaryText: AppColors.primary,
    shadow: Color(0x66000000),
  );

  static const light = AppPalette(
    bg: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDEDF0),
    border: Color(0xFFE3E3E8),
    text: AppColors.charcoal,
    textMuted: Color(0xFF5F6068),
    primaryText: Color(0xFFC24A00),
    shadow: Color(0x14000000),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? primaryText,
    Color? shadow,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      primaryText: primaryText ?? this.primaryText,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Palet sesuai mode aktif. Jika tema tidak memuat [AppPalette] (mis.
  /// `MaterialApp` polos di tes), dipakai palet bawaan menurut kecerahannya.
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppPalette.light);
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  /// Poppins untuk teks, Montserrat tebal untuk judul.
  static TextTheme _textTheme(TextTheme base, AppPalette p) {
    final themed = base.apply(bodyColor: p.text, displayColor: p.text);
    if (!UiConfig.useGoogleFonts) {
      return themed.copyWith(
        displayLarge: themed.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        displayMedium: themed.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        displaySmall: themed.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: themed.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: themed.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: themed.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleLarge: themed.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      );
    }

    final body = GoogleFonts.poppinsTextTheme(themed);
    TextStyle? heading(TextStyle? s) => s == null
        ? null
        : GoogleFonts.montserrat(
            textStyle: s,
            fontWeight: FontWeight.w800,
            color: p.text,
          );
    return body.copyWith(
      displayLarge: heading(themed.displayLarge),
      displayMedium: heading(themed.displayMedium),
      displaySmall: heading(themed.displaySmall),
      headlineLarge: heading(themed.headlineLarge),
      headlineMedium: heading(themed.headlineMedium),
      headlineSmall: heading(themed.headlineSmall),
      titleLarge: heading(themed.titleLarge),
    );
  }

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.primarySoft,
          onSecondary: AppColors.onPrimary,
          error: AppColors.danger,
          surface: p.surface,
          onSurface: p.text,
          onSurfaceVariant: p.textMuted,
          outline: p.border,
          outlineVariant: p.border,
          surfaceContainerLowest: p.bg,
          surfaceContainerLow: p.surface,
          surfaceContainer: p.surface,
          surfaceContainerHigh: p.surfaceAlt,
          surfaceContainerHighest: p.surfaceAlt,
        );

    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, p);
    final roundedLg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [p],
      dividerTheme: DividerThemeData(color: p.border, space: 1),
      iconTheme: IconThemeData(color: p.text),
      listTileTheme: ListTileThemeData(iconColor: p.textMuted),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: AppTextSizes.title,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 15,
        ),
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textMuted),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        disabledBorder: inputBorder(p.border),
        focusedBorder: inputBorder(AppColors.primary, 1.6),
        errorBorder: inputBorder(AppColors.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
          shape: roundedLg,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primaryText,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
          shape: roundedLg,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryText,
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        disabledColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: p.text,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: p.primaryText,
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navBarHeight,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(
          alpha: isDark ? 0.22 : 0.16,
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.primaryText
                : p.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: AppTextSizes.small,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? p.primaryText
                : p.textMuted,
          ),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.primary,
        textColor: AppColors.onPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? p.surfaceAlt : AppColors.charcoal,
        contentTextStyle: const TextStyle(color: Color(0xFFF5F5F7)),
        actionTextColor: AppColors.primarySoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : p.textMuted,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : p.surfaceAlt,
        ),
      ),
    );
  }
}
