import 'package:flutter/material.dart';

/// Temas claro/escuro compartilhados por todos os módulos.
abstract final class BuildSapTema {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEF6C00)),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF6C00),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}