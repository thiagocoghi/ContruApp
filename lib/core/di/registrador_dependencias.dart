import 'package:flutter_bloc/flutter_bloc.dart';

import '../../modulos/diario_obra/apresentacao/bloc/obras_cubit.dart';
import '../../modulos/diario_obra/apresentacao/relatorios/exportar_rdo_pdf.dart';
import '../../modulos/diario_obra/apresentacao/relatorios/gerador_pdf_rdo.dart';
import '../../modulos/diario_obra/dados/fontes_locais/gravador_audio.dart';
import '../../modulos/diario_obra/dados/repositorios/diario_repositorio_sqlite.dart';
import '../../modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_regras.dart';
import '../../modulos/diario_obra/dominio/casos_de_uso/montar_diario_por_voz.dart';
import '../../modulos/diario_obra/dominio/interfaces/extrator_entidades.dart';
import '../../modulos/diario_obra/dominio/interfaces/transcritor.dart';
import '../../modulos/diario_obra/dominio/repositorios/diario_repositorio.dart';
import '../../motor_ia/apresentacao/bloc/preparacao_ia_cubit.dart';
import '../../motor_ia/dados/slm/engine_qwen.dart';
import '../../motor_ia/dados/whisper/transcritor_whisper.dart';
import '../../motor_ia/orquestrador_ia.dart';
import '../dados/banco_dados/conexao/conexao_sqlite.dart';
import '../dados/banco_dados/daos/diarios_dao.dart';
import '../dados/banco_dados/daos/obras_dao.dart';
import '../dados/repositorios/obra_repositorio_sqlite.dart';
import '../dominio/casos_de_uso/criar_obra.dart';
import '../dominio/repositorios/obra_repositorio.dart';

/// Composição raiz das dependências (banco local, repositórios, motor de IA).
///
/// Inicializado uma única vez em `main()`. [instancia] é consultada pelas
/// rotas para construir os Blocs/Cubits de cada tela.
class RegistrarDependencias {
  RegistrarDependencias._({
    required this.obras,
    required this.diarios,
    required this.transcritor,
    required this.extrator,
    required this.orquestradorIa,
    required this.gravador,
    required this.exportarPdf,
  });

  final ObraRepositorio obras;
  final DiarioRepositorio diarios;
  final Transcritor transcritor;
  final ExtratorEntidades extrator;

  /// Motor de IA on-device (Qwen 2.5 1.5B + cascata para as regras).
  ///
  /// O modelo NÃO é baixado na inicialização: a UI chama
  /// [orquestradorIa].preparar() quando quiser (~1 GB, 1ª execução) — até lá
  /// a extração do RDO roda só com [extrator] (regras determinísticas).
  final OrquestradorIa orquestradorIa;

  /// Aliase de [orquestradorIa] para o pipeline da Etapa 1.
  ExtratorEntidadesAsync get extratorIa => orquestradorIa;

  final GravadorAudio gravador;
  final ExportarRdoPdf exportarPdf;

  static RegistrarDependencias? _instancia;
  static RegistrarDependencias get instancia {
    assert(_instancia != null, 'Chame RegistrarDependencias.inicializar()');
    return _instancia!;
  }

  /// Casos de uso dependentes de estado.
  CriarObra get criarObra => CriarObra(obras);

  MontarDiarioPorVoz get montarDiarioPorVoz => MontarDiarioPorVoz(
        transcritor: transcritor,
        extrator: extrator,
        extratorIa: extratorIa,
      );

  /// Inicialização offline-first: abre o SQLite e monta a árvore.
  static Future<RegistrarDependencias> inicializar() async {
    final conexao = await ConexaoSqlite.abrir();

    final diariosDao = DiariosDao(conexao.db);
    final obrasDao = ObrasDao(conexao.db);

    final transcritor = TranscritorWhisper();
    const extrator = ExtratorRdoRegras();
    final orquestradorIa = OrquestradorIa(slm: EngineQwen());

    final diarios = DiarioRepositorioSqlite(diariosDao);

    _instancia = RegistrarDependencias._(
      obras: ObraRepositorioSqlite(obrasDao),
      diarios: diarios,
      transcritor: transcritor,
      extrator: extrator,
      orquestradorIa: orquestradorIa,
      gravador: GravadorAudio(),
      exportarPdf: ExportarRdoPdf(gerador: GeradorPdfRdo(), diarios: diarios),
    );
    return _instancia!;
  }

  /// Providers globais injetados na raiz do app.
  ///
  /// O `PreparacaoIaCubit` nasce aqui e **instala a LLM sozinho** na
  /// inicialização do app (download na 1ª execução, cache nas seguintes) —
  /// com progresso no `BannerInstalacaoIa` da tela inicial.
  List<BlocProvider> get blocProviders => [
        BlocProvider<ObrasCubit>(
          create: (_) => ObrasCubit(
            repositorio: obras,
            criarObra: criarObra,
          )..carregar(),
        ),
        BlocProvider<PreparacaoIaCubit>(
          create: (_) => PreparacaoIaCubit(orquestrador: orquestradorIa)
            ..iniciar(),
        ),
      ];

  Future<void> fechar() async {
    await orquestradorIa.liberar();
    await gravador.liberar();
    _instancia = null;
  }
}