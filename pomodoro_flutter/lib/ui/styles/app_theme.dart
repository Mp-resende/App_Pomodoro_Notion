import 'package:flutter/material.dart';

class AppThemeData {
  final String name;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color surface;
  final Color primaryAccent;     // Neon Principal
  final Color secondaryAccent;   // Neon Secundário
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;

  const AppThemeData({
    required this.name,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.surface,
    required this.primaryAccent,
    required this.secondaryAccent,
    this.textPrimary = Colors.white,
    this.textSecondary = Colors.white70,
    required this.cardBorder,
  });

  static const AppThemeData cyberpunk = AppThemeData(
    name: 'Cyberpunk',
    backgroundStart: Color(0xFF0F172A),
    backgroundEnd: Color(0xFF1E293B),
    surface: Color(0xFF1E293B),
    primaryAccent: Color(0xFF00F2FE),     // Ciano Neon
    secondaryAccent: Color(0xFFFF007F),   // Pink Neon
    cardBorder: Color(0xFF334155),
  );

  static const AppThemeData dracula = AppThemeData(
    name: 'Dracula',
    backgroundStart: Color(0xFF1A1A24),
    backgroundEnd: Color(0xFF282A36),
    surface: Color(0xFF282A36),
    primaryAccent: Color(0xFFBD93F9),     // Roxo Neon
    secondaryAccent: Color(0xFF50FA7B),   // Verde Limão Neon
    cardBorder: Color(0xFF44475A),
  );

  static const AppThemeData matrix = AppThemeData(
    name: 'Matrix',
    backgroundStart: Color(0xFF060907),
    backgroundEnd: Color(0xFF0F1410),
    surface: Color(0xFF141A15),
    primaryAccent: Color(0xFF39FF14),     // Verde Terminal Neon
    secondaryAccent: Color(0xFF008F11),   // Verde Escuro Neon
    cardBorder: Color(0xFF222F24),
  );

  static const AppThemeData forest = AppThemeData(
    name: 'Forest',
    backgroundStart: Color(0xFF0B1410),
    backgroundEnd: Color(0xFF13221C),
    surface: Color(0xFF1B2F26),
    primaryAccent: Color(0xFF00E676),     // Esmeralda Neon
    secondaryAccent: Color(0xFFFFD700),   // Ouro/Amarelo Neon
    cardBorder: Color(0xFF274337),
  );

  static AppThemeData getTheme(String name) {
    switch (name.toLowerCase()) {
      case 'dracula':
        return dracula;
      case 'matrix':
        return matrix;
      case 'forest':
        return forest;
      case 'cyberpunk':
      default:
        return cyberpunk;
    }
  }
}
