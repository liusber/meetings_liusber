import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'settings.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = MeetingStore();
  final settings = AppSettings();
  await Future.wait([store.load(), settings.load()]);
  runApp(CopilotoApp(store: store, settings: settings));
}

class CopilotoApp extends StatelessWidget {
  final MeetingStore store;
  final AppSettings settings;

  const CopilotoApp({super.key, required this.store, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meeting Copilot',
      debugShowCheckedModeBanner: false,
      theme: appleTheme(Brightness.light),
      darkTheme: appleTheme(Brightness.dark),
      home: HomeScreen(store: store, settings: settings),
    );
  }
}

/// Tema estilo Apple: fondo gris claro, tarjetas blancas redondeadas, acento
/// azul y la letra del sistema (SF en Mac y iPhone). Sigue el modo oscuro del equipo.
ThemeData appleTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
  final card = dark ? const Color(0xFF1C1C1E) : Colors.white;
  final fill = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  final line = dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  final text = dark ? Colors.white : const Color(0xFF1D1D1F);
  final dim = dark ? const Color(0xFF98989D) : const Color(0xFF6E6E73);
  final blue = dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  final scheme = ColorScheme(
    brightness: b,
    primary: blue,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xFF0A2A4D) : const Color(0xFFE8F1FD),
    onPrimaryContainer: dark ? const Color(0xFFCFE3FF) : const Color(0xFF003A75),
    secondary: dim,
    onSecondary: Colors.white,
    secondaryContainer: fill,
    onSecondaryContainer: text,
    tertiary: dark ? const Color(0xFF30D158) : const Color(0xFF248A3D),
    onTertiary: Colors.white,
    tertiaryContainer: fill,
    onTertiaryContainer: text,
    error: dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
    onError: Colors.white,
    surface: bg,
    onSurface: text,
    onSurfaceVariant: dim,
    surfaceContainerLowest: card,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: fill,
    surfaceContainerHighest: fill,
    outline: dim,
    outlineVariant: line,
    inverseSurface: text,
    onInverseSurface: bg,
  );
  const radius = BorderRadius.all(Radius.circular(10));
  const pill = StadiumBorder();
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: bg);
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 44,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: text),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: blue, width: 2)),
      labelStyle: TextStyle(color: dim),
      hintStyle: TextStyle(color: dim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: pill, foregroundColor: blue, side: BorderSide(color: line)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: blue)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: blue,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: pill,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: blue,
      unselectedLabelColor: dim,
      indicatorColor: blue,
      dividerColor: line,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: fill,
        selectedBackgroundColor: card,
        selectedForegroundColor: text,
        foregroundColor: dim,
        side: BorderSide(color: line),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: blue,
      selectedTileColor: dark ? const Color(0xFF0A2A4D) : const Color(0xFFE8F1FD),
      shape: const RoundedRectangleBorder(borderRadius: radius),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: blue, inactiveTrackColor: line, thumbColor: Colors.white),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: blue),
  );
}
