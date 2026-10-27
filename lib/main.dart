import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/di/registrador_dependencias.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização offline-first: banco local + motor de IA on-device
  final dependencias = await RegistrarDependencias.inicializar();

  runApp(
    MultiBlocProvider(
      providers: dependencias.blocProviders,
      child: const BuildSapApp(),
    ),
  );
}