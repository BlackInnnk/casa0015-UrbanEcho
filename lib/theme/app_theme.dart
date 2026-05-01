part of urbanecho;

const Color _cream = Color(0xFFF5F0E8);
const Color _paper = Color(0xFFEDE8DC);
const Color _paperDark = Color(0xFFD9D2C0);
const Color _paperSurface = Colors.white;
const Color _paperSoft = Color(0xFFF0E4D0);
const Color _paperLine = Color(0xFFC8BFA8);
const Color _deepBrown = Color(0xFF4A3420);
const Color _brown = Color(0xFF7A5C3A);
const Color _ink = Color(0xFF2E2518);
const Color _mutedInk = Color(0xFF7B6755);
const Color _terracotta = Color(0xFFC4633A);
const Color _terracottaSoft = Color(0xFFF5DDD3);
const Color _teal = Color(0xFF4A8C80);
const Color _tealSoft = Color(0xFFD4EAE6);
const Color _amber = Color(0xFFB07A40);
const Color _amberSoft = Color(0xFFF0E4D0);

ThemeData _buildUrbanEchoTheme() {
  return ThemeData(
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: _terracotta,
          brightness: Brightness.light,
        ).copyWith(
          primary: _terracotta,
          secondary: _teal,
          surface: _paperSurface,
          onSurface: _ink,
          outline: _paperLine,
        ),
    scaffoldBackgroundColor: _cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _paper,
      indicatorColor: _terracottaSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: _paperSurface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _paperSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _paperLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _paperLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _terracotta, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _paperSurface,
      selectedColor: _terracottaSoft,
      side: const BorderSide(color: _paperLine),
      labelStyle: const TextStyle(color: _ink),
      secondaryLabelStyle: const TextStyle(color: _ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _terracotta,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _brown,
        side: const BorderSide(color: _paperLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: _ink,
      displayColor: _ink,
    ),
    useMaterial3: true,
  );
}
