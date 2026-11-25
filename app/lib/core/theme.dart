import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Life Tracker Pro design tokens — see docs/DESIGN_SYSTEM.md
class AppColors {
  // Brand
  static const primary = Color(0xFF6366F1);
  /// Readable "link" blue/indigo for text and icons on the app background.
  static const linkDark = Color(0xFFC3C6FF);
  static const linkLight = Color(0xFF3438C4);
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
  // Deep enough at both ends to carry white text (the light ends used to wash it out).
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
    colors: [Color(0xFF047857), Color(0xFF059669)],
    begin: _tl,
    end: _br,
  );
  static const expenseGrad = LinearGradient(
    colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
    begin: _tl,
    end: _br,
  );
  static const savingsGrad = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF0284C7)],
    begin: _tl,
    end: _br,
  );
  static const warningGrad = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFD97706)],
    begin: _tl,
    end: _br,
  );
  static const accentGrad = LinearGradient(
    colors: [Color(0xFF0E7490), Color(0xFF0891B2)],
    begin: _tl,
    end: _br,
  );

  // App-wide colorful background gradients
  static const darkBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B2D83), Color(0xFF24408A), Color(0xFF17506A), Color(0xFF1B3F4F)],
  );
  static const lightBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD9EC), Color(0xFFE6D8FF), Color(0xFFFFF3C4), Color(0xFFFFDCEB), Color(0xFFEBDDFF)],
    stops: [0.0, 0.28, 0.52, 0.76, 1.0],
  );

  static const midnightBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0F1A), Color(0xFF131A2B), Color(0xFF0A0E17)],
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
  static const m = SizedBox(height: 10, width: 10);
  static const l = SizedBox(height: 12, width: 12);
  static const xl = SizedBox(height: 18, width: 18);
}

/// Colours for text and icons drawn straight on the app background (outside cards).
/// The three backgrounds are fixed (Pastel light, Aurora / Midnight dark), so this
/// simply follows the theme; widgets use it for anything that is not on a card.
@immutable
class BgInk extends ThemeExtension<BgInk> {
  const BgInk({required this.dark});

  /// Whether the app background is dark (so light text goes on it).
  final bool dark;

  Color get text => dark ? AppColors.dOnBackground : AppColors.lOnBackground;
  Color get muted => dark ? const Color(0xFFB4BAC4) : AppColors.lMuted;
  Color get link => dark ? AppColors.linkDark : AppColors.linkLight;

  /// Status-bar / navigation-bar icon style for this background.
  SystemUiOverlayStyle get overlay => (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
      .copyWith(statusBarColor: Colors.transparent);

  static BgInk of(BuildContext context) =>
      Theme.of(context).extension<BgInk>() ??
      BgInk(dark: Theme.of(context).brightness == Brightness.dark);

  @override
  BgInk copyWith({bool? dark}) => BgInk(dark: dark ?? this.dark);

  @override
  BgInk lerp(BgInk? other, double t) => t < 0.5 || other == null ? this : other;
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final ink = BgInk(dark: dark);
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
      // Dropdown menus (DropdownButtonFormField) paint on canvasColor: keep it the
      // solid surface so their onSurface text is always readable.
      canvasColor: dark ? AppColors.dSurface : AppColors.lSurface,
      fontFamily: 'Roboto',
    );

    final muted = dark ? AppColors.dMuted : AppColors.lMuted;

    return base.copyWith(
      extensions: [ink],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // The bar is see-through, so its text sits on the app background.
        foregroundColor: ink.text,
        systemOverlayStyle: ink.overlay,
      ),
      // Tab bars live in the see-through app bar, i.e. on the app background.
      tabBarTheme: TabBarThemeData(
        labelColor: ink.link,
        unselectedLabelColor: ink.muted,
        indicatorColor: ink.link,
        dividerColor: ink.muted.withValues(alpha: 0.3),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Unselected segments get a solid surface so their text never sits on the
          // (possibly light or dark) app background.
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.accent : scheme.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.black : scheme.onSurface),
          iconColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.black : scheme.onSurface),
        ),
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
        textStyle: TextStyle(color: scheme.onSurface),
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
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        minVerticalPadding: 4,
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
          foregroundColor: dark ? AppColors.linkDark : AppColors.linkLight,
          // Solid fill so the label never depends on what is behind the button.
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? AppColors.linkDark : AppColors.linkLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      // copyWith on the base styles keeps their colours: plain TextStyles here used to
      // drop them, so e.g. dropdown items / sheet titles (titleMedium) had no colour
      // of their own and picked up whatever was around them.
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600, color: scheme.onSurface),
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
