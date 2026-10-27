/// Contrato de transcrição de áudio → texto (STT, 100% on-device).
///
/// Implementado em `motor_ia/dados/whisper` com o whisper.cpp.
abstract interface class Transcritor {
  /// Transcreve um arquivo de áudio no dispositivo.
  ///
  /// [idioma] usa códigos BCP-47 ('pt', 'en', 'auto'...).
  Future<String> transcrever({
    required String caminhoAudio,
    String idioma = 'pt',
  });
}