import 'package:flutter/material.dart';

import '../core/apresentacao/tema/tema.dart';
import 'rotas.dart';

/// Raiz do EnginApp.
class BuildSapApp extends StatelessWidget {
  const BuildSapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EnginApp',
      theme: BuildSapTema.light,
      darkTheme: BuildSapTema.dark,
      onGenerateRoute: gerarRota,
      debugShowCheckedModeBanner: false,
    );
  }
}