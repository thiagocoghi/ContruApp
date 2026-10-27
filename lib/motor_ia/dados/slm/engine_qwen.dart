import 'package:llamadart/llamadart.dart';

import '../../dominio/interfaces/inferencia_slm.dart';

/// Qwen 2.5 1.5B Instruct rodando 100% no aparelho (PRD Seção 2.1).
///
/// Usa o pacote `llamadart` (llama.cpp) com runtime nativo resolvido pelo
/// build hook — sem toolchain C++. O GGUF quantizado (Q4_K_M, ~1 GB) é
/// baixado do Hugging Face na primeira execução e fica no cache do pacote
/// (diretório de cache do app no Android/iOS); depois disso a inferência é
/// totalmente offline.
class EngineQwen implements InferenciaSlm {
  EngineQwen({
    this.fonte = fontePadrao,
    this.contexto = 2048,
    this.maxTokensPadrao = 384,
  });

  /// Qwen2.5-1.5B-Instruct em Q4_K_M (~1 GB): melhor relação qualidade/tam.
  /// O nome do arquivo no repositório oficial é minúsculo — o Q maiúsculo
  /// devolve HTTP 404.
  static const fontePadrao =
      'hf://Qwen/Qwen2.5-1.5B-Instruct-GGUF/'
      'qwen2.5-1.5b-instruct-q4_k_m.gguf';

  /// URI do modelo: `hf://donorepo/arquivo.gguf`, URL http(s) ou caminho
  /// local (usado no desktop pelo script `native/scripts/baixar_modelo_qwen.sh`).
  final String fonte;

  /// Contexto de 2048 tokens é suficiente para transcrições de RDO e mantém
  /// o consumo de RAM compatível com celulares de entrada (PRD: 1B–3B params).
  final int contexto;

  final int maxTokensPadrao;

  LlamaEngine? _engine;
  Future<void>? _carregamento;

  @override
  bool get pronto => _engine?.isReady ?? false;

  @override
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) async {
    if (pronto) return;

    // Chamadas concorrentes compartilham o mesmo carregamento.
    final emAndamento = _carregamento;
    if (emAndamento != null) return emAndamento;

    final carregamento = _carregar(aoProgresso);
    _carregamento = carregamento;
    try {
      await carregamento;
    } catch (_) {
      // Load que falha já descarta o engine; destravar a próxima tentativa.
      _carregamento = null;
      rethrow;
    }
  }

  Future<void> _carregar(void Function(double? fracao)? aoProgresso) async {
    final engine = await LlamaEngine.load(
      LlamaModel(ModelSource.parse(fonte)),
      // `device` fica em `auto`: Metal no iOS, CPU no Android (GPU Adreno
      // ainda é experimental no llama.cpp e o PRD prioriza estabilidade).
      params: ModelParams(contextSize: contexto),
      onProgress: (ModelDownloadProgress progress) {
        aoProgresso?.call(progress.fraction);
      },
    );
    _engine = engine;
  }

  @override
  Future<String> completar({
    required String instrucao,
    required String entrada,
    int maxTokens = 384,
  }) async {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw StateError(
        'Modelo Qwen não carregado — chame preparar() antes de completar().',
      );
    }

    final resposta = engine.create(
      [
        LlamaChatMessage.fromText(role: LlamaChatRole.system, text: instrucao),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: entrada),
      ],
      // Baixa temperatura: a saída é JSON estruturado, não texto criativo.
      params: GenerationParams(maxTokens: maxTokens, temp: 0.1),
    );
    return resposta.text().then((texto) => texto.trim());
  }

  @override
  Future<void> liberar() async {
    final carregamento = _carregamento;
    if (carregamento != null) {
      try {
        await carregamento;
      } catch (_) {
        // Carga que falhou já deixou o engine descartado pelo próprio load.
      }
    }

    final engine = _engine;
    _engine = null;
    _carregamento = null;
    if (engine != null) await engine.dispose();
  }
}
