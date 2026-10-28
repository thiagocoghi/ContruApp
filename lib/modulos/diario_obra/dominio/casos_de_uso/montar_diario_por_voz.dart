import '../../../../core/dominio/erros/falha_dominio.dart';
import '../../../../core/infra/util/gerador_ids.dart';
import '../entidades/diario_obra.dart';
import '../entidades/extracao_rdo.dart';
import '../interfaces/extrator_entidades.dart';
import '../interfaces/transcritor.dart';

/// Pipeline da Etapa 1 do PRD:
///
/// `áudio ──(whisper)──► texto bruto ──(regras/SLM)──► RDO estruturado`
///
/// Não persiste nada — o RDO só é salvo quando o usuário confirma na UI.
class MontarDiarioPorVoz {
  const MontarDiarioPorVoz({
    required this.transcritor,
    required this.extrator,
    this.extratorIa,
  });

  final Transcritor transcritor;

  /// Extração determinística — sempre presente e usada quando não há
  /// [extratorIa] (ou quando ele cai no fallback das regras).
  final ExtratorEntidades extrator;

  /// Extração assíncrona com SLM on-device (cascata Qwen → regras), montada
  /// na DI pelo `OrquestradorIa`. Opcional: sem ela o pipeline é 100% regras.
  final ExtratorEntidadesAsync? extratorIa;

  Future<DiarioObra> executar({
    required String caminhoAudio,
    required String obraId,
    DateTime? agora,
  }) async {
    // idioma 'auto': o whisper detecta sozinho o idioma falado em cada
    // gravação, em vez de forçar PT-BR sobre qualquer fala.
    final texto = await transcritor.transcrever(
      caminhoAudio: caminhoAudio,
      idioma: 'auto',
    );

    if (texto.isEmpty) {
      throw const FalhaDominio(
        'Não foi possível transcrever o áudio. '
        'Fale mais perto do microfone e tente novamente.',
      );
    }

    // O contrato de ExtratorEntidadesAsync proíbe exceção, mas a IA nunca
    // pode derrubar o fluxo de gravação: qualquer erro cai para as regras.
    ExtracaoRdo extracao;
    final assincrono = extratorIa;
    if (assincrono == null) {
      extracao = extrator.extrair(texto);
    } else {
      try {
        extracao = await assincrono.extrair(texto);
      } catch (_) {
        extracao = extrator.extrair(texto);
      }
    }

    return DiarioObra(
      id: gerarId(),
      obraId: obraId,
      data: agora ?? DateTime.now(),
      transcricaoRaw: texto,
      clima: extracao.clima,
      efetivo: extracao.efetivo,
      materiais: extracao.materiais,
      ocorrencias: extracao.ocorrencias,
      prazos: extracao.prazos,
    );
  }
}