import '../modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_ia.dart';
import '../modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_regras.dart';
import '../modulos/diario_obra/dominio/entidades/extracao_rdo.dart';
import '../modulos/diario_obra/dominio/interfaces/extrator_entidades.dart';
import 'dominio/interfaces/inferencia_slm.dart';

/// Orquestrador do motor de IA da Etapa 1: decide quem extrai as entidades do
/// RDO e garante que a IA nunca seja um ponto de falha do app.
///
/// Cascata (PRD, Seção 2 — "IA auxilia, regra decide"):
///
/// 1. **SLM on-device** (Qwen 2.5 1.5B) — quando o modelo já está pronto;
/// 2. **regras determinísticas** ([ExtratorRdoRegras]) — quando o SLM não
///    está carregado (download ainda não aconteceu, aparelho sem espaço),
///    devolveu JSON inválido, respondeu vazio ou lançou qualquer erro.
///
/// O download/carregamento é explícito ([preparar]), nunca automático: o app
/// permanece 100% funcional offline sem o modelo, que ocupa ~1 GB.
class OrquestradorIa implements ExtratorEntidadesAsync {
  OrquestradorIa({
    required this.slm,
    this.extratorRegras = const ExtratorRdoRegras(),
  });

  /// Motor de inferência (Qwen 2.5 1.5B via llama.cpp).
  final InferenciaSlm slm;

  /// Extrator determinístico — sempre disponível, é o piso de qualidade.
  final ExtratorEntidades extratorRegras;

  late final ExtratorRdoIa _extratorIa = ExtratorRdoIa(slm: slm);

  /// SLM pronto para uso (modelo baixado e em memória).
  bool get iaDisponivel => slm.pronto;

  /// Baixa (1ª execução) e carrega o modelo. Chamar por conta própria — por
  /// exemplo num botão "Preparar IA" ou antes do primeiro uso — com um
  /// [aoProgresso] para a barra de download.
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) =>
      slm.preparar(aoProgresso: aoProgresso);

  /// Libera a memória do modelo; o próximo [preparar] recarrega do cache.
  Future<void> liberar() => slm.liberar();

  @override
  Future<ExtracaoRdo> extrair(String texto) async {
    // Calculado antes: é barato e serve de resposta imediata em qualquer falha.
    final regras = extratorRegras.extrair(texto);
    if (!slm.pronto) return regras;

    try {
      final ia = await _extratorIa.extrair(texto);
      if (!ia.vazio) return ia;
      // Resposta válida porém vazia: o modelo não enxergou entidades —
      // as regras cobrem melhor o mesmo texto.
      return regras;
    } catch (_) {
      // Silencioso por decisão: offline-first, o fallback é o comportamento
      // esperado. A validação do motor em si é feita por
      // `native/scripts/teste_inferencia.dart`.
      return regras;
    }
  }
}
