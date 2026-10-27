import 'package:flutter/material.dart';

import '../core/dominio/entidades/obra.dart';
import '../modulos/diario_obra/apresentacao/telas/tela_criar_obra.dart';
import '../modulos/diario_obra/apresentacao/telas/tela_detalhe_diario.dart';
import '../modulos/diario_obra/apresentacao/telas/tela_diarios.dart';
import '../modulos/diario_obra/apresentacao/telas/tela_gravacao.dart';
import '../modulos/diario_obra/apresentacao/telas/tela_obras.dart';
import '../modulos/diario_obra/dominio/entidades/diario_obra.dart';

/// Gerador de rotas do app.
///
/// Etapa 1 do roadmap (Seção 3 do PRD) ativa:
/// - `/`                 → lista de obras
/// - `/obra/nova`        → cadastro de obra
/// - `/obra/diarios`     → RDOs da obra (args: [Obra])
/// - `/diario/nova`      → gravação por voz (args: [Obra])
/// - `/diario/detalhe`   → detalhe do RDO (args: ({Obra, DiarioObra}))
///
/// Etapas 2-5 registrarão suas rotas aqui em seguida.
Route<dynamic>? gerarRota(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const TelaObras());
    case '/obra/nova':
      return MaterialPageRoute(builder: (_) => const TelaCriarObra());
    case '/obra/diarios':
      final obra = settings.arguments as Obra;
      return MaterialPageRoute(builder: (_) => TelaDiarios(obra: obra));
    case '/diario/nova':
      final obra = settings.arguments as Obra;
      return MaterialPageRoute(builder: (_) => TelaGravacao(obra: obra));
    case '/diario/detalhe':
      final args = settings.arguments as ({Obra obra, DiarioObra diario});
      return MaterialPageRoute(
        builder: (_) => TelaDetalheDiario(obra: args.obra, diario: args.diario),
      );
    default:
      return MaterialPageRoute(builder: (_) => const TelaObras());
  }
}