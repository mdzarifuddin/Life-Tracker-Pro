import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Life Tracker Pro design tokens — see docs/DESIGN_SYSTEM.md
class AppColors {
  // Brand
  static const primary = Color(0xFF6366F1);
  static const primaryContainer = Color(0xFF4F46E5);
  static const accent = Color(0xFF22D3EE);

  // Semantic
  static const income = Color(0xFF10B981);
  static const expense = Color(0xFFF43F5E);
  static const warning = Color(0xFFF59E0B);
  static const savings = Color(0xFF3B82F6);
  static const info = Color(0xFF0EA5E9);

  // Dark surfaces
  static const dBackground = Color(0xFF0F1115);
  static const dSurface = Color(0xFF161A20);
  static const dSurfaceVariant = Color(0xFF1F242C);
  static const dOutline = Color(0xFF2A2F37);
  static const dOnBackground = Color(0xFFE6E8EC);
  static const dMuted = Color(0xFF9AA1AC);

  // Light surfaces
  static const lBackground = Color(0xFFF7F8FA);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceVariant = Color(0xFFEEF0F3);
  static const lOutline = Color(0xFFE2E5EA);
  static const lOnBackground = Color(0xFF1A1D21);
  static const lMuted = Color(0xFF5C636E);

  /// Category / calendar palette (assign cyclically).
  static const palette = <Color>[
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF43F5E),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
  ];

  static Color forIndex(int i) => palette[i % palette.length];

  // ---- Gradients (colorful / modern) ----
  static const _tl = Alignment.topLeft;
  static const _br = Alignment.bottomRight;
  static const hero = LinearGradient(
    colors: [Color(0xFF6D5DF6), Color(0xFF9333EA), Color(0xFFEC4899)],
    begin: _tl,
    end: _br,
  );
  static const primaryGrad = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: _tl,
    end: _br,
  );
  static const incomeGrad = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF34D399)],
    begin: _tl,
    end: _br,
  );
  static const expenseGrad = LinearGradient(
    colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
    begin: _tl,
    end: _br,
  );
  static const savingsGrad = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
    begin: _tl,
    end: _br,
  );
  static const warningGrad = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
    begin: _tl,
    end: _br,
  );
  static const accentGrad = LinearGradient(
    colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
    begin: _tl,
    end: _br,
  );

  // App-wide colorful background gradients
  static const darkBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241A4D), Color(0xFF15224A), Color(0xFF0E1626)],
  );
  static const lightBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFECEDFF), Color(0xFFFBEAF4), Color(0xFFE6F2FF)],
  );

  static const moduleGrads = <LinearGradient>[
    incomeGrad,
    warningGrad,
    savingsGrad,
    primaryGrad,
    accentGrad,
  ];
  static LinearGradient gradFor(int i) => moduleGrads[i % moduleGrads.length];
}

/// Spacing scale (dp): 4 8 12 16 20 24 32 48
class Gap {
  static const xs = SizedBox(height: 4, width: 4);
  static const s = SizedBox(height: 8, width: 8);
  static const m = SizedBox(height: 12, width: 12);
  static const l = SizedBox(height: 16, width: 16);
  static const xl = SizedBox(height: 24, width: 24);
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      error: AppColors.expense,
      onError: Colors.white,
      surface: dark ? AppColors.dSurface : AppColors.lSurface,
      onSurface: dark ? AppColors.dOnBackground : AppColors.lOnBackground,
      onSurfaceVariant: dark ? AppColors.dMuted : AppColors.lMuted,
      surfaceContainerLowest: dark
          ? AppColors.dBackground
          : AppColors.lBackground,
      surfaceContainerLow: dark ? AppColors.dSurface : AppColors.lSurface,
      surfaceContainer: dark
          ? AppColors.dSurfaceVariant
          : AppColors.lSurfaceVariant,
      surfaceContainerHigh: dark
          ? AppColors.dSurfaceVariant
          : AppColors.lSurfaceVariant,
      surfaceContainerHighest: dark
          ? AppColors.dSurfaceVariant
          : AppColors.lSurfaceVariant,
      outline: dark ? AppColors.dOutline : AppColors.lOutline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
    );

    final muted = dark ? AppColors.dMuted : AppColors.lMuted;

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: dark
            ? AppColors.dOnBackground
            : AppColors.lOnBackground,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.dSurface : AppColors.lSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? AppColors.dSurface : AppColors.lSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: dark ? AppColors.dOnBackground : AppColors.lOnBackground,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? AppColors.dSurface : AppColors.lSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            dark ? AppColors.dSurface : AppColors.lSurface,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF2B3140)
            : const Color(0xFF2B2F3A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        selectedColor: AppColors.accent,
        checkmarkColor: Colors.black,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: dark ? AppColors.dOnBackground : AppColors.lOnBackground,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: scheme.outline,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(8),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: dark ? 1 : 0.6),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: (dark ? AppColors.dSurface : AppColors.lSurface)
            .withValues(alpha: 0.92),
        indicatorColor: AppColors.primary.withValues(alpha: 0.28),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.primary : muted,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
        ),
        height: 66,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.dSurfaceVariant : AppColors.lSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.expense, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.expense, width: 2),
        ),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(
          color: dark ? AppColors.dOnBackground : AppColors.lOnBackground,
        ),
      ),
    );
  }
}

/// Money formatter: "৳ 27,000"
String taka(num v) => '৳ ${NumberFormat('#,##0', 'en_US').format(v)}';

String shortDate(DateTime d) => DateFormat('d MMM').format(d);
String fullDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

IconData iconForCategory(String name) {
  switch (name.toLowerCase()) {
    case 'food':
      return Icons.restaurant;
    case 'transport':
    case 'tuition travel':
      return Icons.directions_bus;
    case 'internet':
      return Icons.wifi;
    case 'mobile recharge':
    case 'mobile':
      return Icons.smartphone;
    case 'books':
      return Icons.menu_book;
    case 'family':
      return Icons.family_restroom;
    case 'medical':
      return Icons.local_hospital;
    case 'shopping':
      return Icons.shopping_bag;
    case 'entertainment':
      return Icons.movie;
    case 'govt job':
      return Icons.account_balance;
    case 'thesis':
      return Icons.school;
    case 'software':
      return Icons.code;
    case 'subscriptions':
      return Icons.subscriptions;
    case 'investment':
      return Icons.trending_up;
    case 'grocery':
      return Icons.local_grocery_store;
    case 'tuition':
      return Icons.cast_for_education;
    case 'freelancing':
      return Icons.laptop_mac;
    case 'scholarship':
      return Icons.workspace_premium;
    case 'gift':
      return Icons.card_giftcard;
    case 'salary':
      return Icons.payments;
    case 'business':
      return Icons.storefront;
    default:
      return Icons.category;
  }
}
