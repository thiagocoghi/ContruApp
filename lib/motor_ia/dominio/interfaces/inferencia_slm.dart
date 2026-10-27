/// Contrato do motor de linguagem pequeno (SLM) on-device.
///
/// O PRD (Seção 2.1) prevê Gemma 2B / Qwen 2.5 1.5B / Llama 3.2 quantizados
/// em GGUF, inferindo 100% local — sem servidor e sem rede depois do
/// primeiro download do modelo. Esta interface é o que o restante do app
/// enxerga; a implementação concreta (`EngineQwen`, sobre llama.cpp) fica em
/// `motor_ia/dados/slm/` e o ciclo de vida é orquestrado por
/// `motor_ia/orquestrador_ia.dart`.
abstract interface class InferenciaSlm {
  /// Modelo já baixado (1ª execução), carregado em memória e apto a inferir.
  bool get pronto;

  /// Garante o modelo em memória, baixando-o no primeiro uso.
  ///
  /// Idempotente e concorrência-segura: chamadas simultâneas compartilham o
  /// mesmo carregamento. [aoProgresso] recebe a fração do download
  /// (`null` enquanto o tamanho total é desconhecido).
  Future<void> preparar({void Function(double? fracao)? aoProgresso});

  /// Gera texto a partir de uma instrução de sistema + a entrada do usuário.
  ///
  /// Lança [StateError] se o modelo não estiver pronto — quem chama deve
  /// tratar a falha (o orquestrador cai para as regras determinísticas).
  Future<String> completar({
    required String instrucao,
    required String entrada,
    int maxTokens = 384,
  });

  /// Libera a memória do modelo. Um novo [preparar] recarrega do cache local,
  /// sem novo download.
  Future<void> liberar();
}
