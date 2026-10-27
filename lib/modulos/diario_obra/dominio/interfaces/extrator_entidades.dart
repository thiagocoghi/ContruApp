import '../entidades/extracao_rdo.dart';

/// Contrato de extração de entidades do RDO a partir do texto transcrito.
///
/// O PRD prevê dois motores: extração determinística (Etapa 1) e
/// extração via SLM on-device (Gemma/Qwen) quando o modelo estiver
/// integrado — ambos implementam esta interface.
abstract interface class ExtratorEntidades {
  ExtracaoRdo extrair(String texto);
}

/// Variante assíncrona para extração que passa por inferência on-device
/// (rede + carregamento do modelo) — a cascata SLM → regras vive em
/// `motor_ia/orquestrador_ia.dart`.
///
/// Contrato: **nunca lança exceção**. Sem SLM pronto, JSON inválido ou
/// qualquer falha de inferência, quem implementa devolve o resultado do
/// extrator determinístico, de modo que o pipeline da Etapa 1 não quebra.
abstract interface class ExtratorEntidadesAsync {
  Future<ExtracaoRdo> extrair(String texto);
}