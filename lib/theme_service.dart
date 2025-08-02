import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static bool _isDarkMode = false;
  static bool get isDarkMode => _isDarkMode;

  static final ValueNotifier<bool> _themeNotifier = ValueNotifier<bool>(false);
  static ValueNotifier<bool> get themeNotifier => _themeNotifier;

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeNotifier.value = _isDarkMode;
      print('🎨 Tema servisi başlatıldı: $_isDarkMode');
    } catch (e) {
      print('❌ Tema servisi başlatılamadı: $e');
    }
  }

  static Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      _themeNotifier.value = _isDarkMode;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      
      print('🔄 Tema değiştirildi: $_isDarkMode');
    } catch (e) {
      print('❌ Tema değiştirilemedi: $e');
    }
  }

  static Future<void> setTheme(bool isDark) async {
    try {
      _isDarkMode = isDark;
      _themeNotifier.value = _isDarkMode;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      
      print('🎨 Tema ayarlandı: $_isDarkMode');
    } catch (e) {
      print('❌ Tema ayarlanamadı: $e');
    }
  }

  static ThemeData get lightTheme {
    final lightColorScheme = ColorScheme.light(
      primary: Colors.deepPurple,
      secondary: Colors.deepPurple.shade300,
      surface: Colors.white,
      background: Colors.grey.shade50,  // Daha nötr bir arka plan
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.grey.shade900,  // Daha koyu metin rengi
      onBackground: Colors.grey.shade900,
      error: Colors.red.shade700,
      onError: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: lightColorScheme.background,
      
      // AppBar teması
      appBarTheme: AppBarTheme(
        backgroundColor: lightColorScheme.primary,
        foregroundColor: lightColorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightColorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Kart teması
      cardTheme: CardThemeData(
        color: lightColorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Buton teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Text buton teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightColorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input dekorasyon teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightColorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: lightColorScheme.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: lightColorScheme.onSurface.withOpacity(0.5)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final darkColorScheme = ColorScheme.dark(
      primary: Colors.deepPurple.shade300,
      secondary: Colors.deepPurple.shade200,
      surface: Color(0xFF1D1B20),  // Material 3 Dark Theme surface rengi
      background: Color(0xFF1C1B1F),  // Material 3 Dark Theme background rengi
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white.withOpacity(0.87),  // Daha yumuşak beyaz
      onBackground: Colors.white.withOpacity(0.87),
      error: Colors.red.shade300,  // Daha yumuşak hata rengi
      onError: Colors.white,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: darkColorScheme.background,
      
      // AppBar teması
      appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.surface,
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Kart teması
      cardTheme: CardThemeData(
        color: darkColorScheme.surface,
        elevation: 2,  // Daha az gölge
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Buton teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: darkColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Text buton teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkColorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input dekorasyon teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkColorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkColorScheme.primary.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkColorScheme.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkColorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: darkColorScheme.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: darkColorScheme.onSurface.withOpacity(0.5)),
      ),
    );
  }

  static ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;
} 