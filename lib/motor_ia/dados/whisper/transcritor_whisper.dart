import 'package:whisper_ggml/whisper_ggml.dart';

import '../../../core/dominio/erros/falha_dominio.dart';
import '../../../modulos/diario_obra/dominio/interfaces/transcritor.dart';

/// Transcrição 100% on-device com whisper.cpp (Etapa 1 do PRD).
///
/// Usa o plugin `whisper_ggml` (whisper.cpp v1.9.1) com bindings nativos
/// para Android/iOS/Windows. O modelo GGML é baixado uma única vez e fica
/// em cache no dispositivo — depois disso a transcrição roda sem rede.
class TranscritorWhisper implements Transcritor {
  TranscritorWhisper({this.modelo = WhisperModel.tiny});

  /// PRD: Whisper Tiny ou Base quantizado para PT-BR.
  final WhisperModel modelo;

  @override
  Future<String> transcrever({
    required String caminhoAudio,
    String idioma = 'pt',
  }) async {
    final controller = WhisperController();

    // O plugin NÃO baixa o modelo dentro de `transcribe` — sem este passo a
    // transcrição falha com "failed to load model" e volta vazia.
    await _garantirModelo(controller);

    final resultado = await controller.transcribe(
      model: modelo,
      audioPath: caminhoAudio,
      lang: idioma,
    );
    return (resultado?.transcription.text ?? '').trim();
  }

  /// Garante o modelo GGML local (só na 1ª execução; depois fica em cache).
  Future<void> _garantirModelo(WhisperController controller) async {
    try {
      await controller.downloadModel(modelo);
    } on Exception catch (erro) {
      throw FalhaDominio(
        'O modelo de transcrição (~75 MB) ainda não está no aparelho e não '
        'foi possível baixá-lo agora. Conecte-se à internet e tente '
        'novamente. Detalhe: $erro',
      );
    }
  }
}
