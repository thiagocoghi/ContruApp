import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Gravador de áudio do Diário de Obra.
///
/// Grava WAV 16 kHz mono — exatamente o formato que o whisper.cpp consome
/// sem passar por conversão (funciona offline, sem FFmpeg).
class GravadorAudio {
  final AudioRecorder _gravador = AudioRecorder();

  /// Pede a permissão de microfone (explica na UI o motivo: transcrição
  /// local, o áudio nunca sai do aparelho).
  Future<bool> temPermissao() => _gravador.hasPermission();

  /// Caminho de um novo arquivo de gravação no diretório do app.
  Future<String> caminhoNovo() async {
    final diretorio = await getApplicationDocumentsDirectory();
    final nome = 'gravacao_${DateTime.now().millisecondsSinceEpoch}.wav';
    return p.join(diretorio.path, nome);
  }

  Future<void> iniciar({required String caminhoDestino}) async {
    await _gravador.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: caminhoDestino,
    );
  }

  /// Para a gravação e retorna o caminho do arquivo salvo.
  Future<String?> parar() => _gravador.stop();

  Future<bool> estaGravando() => _gravador.isRecording();

  Future<void> descartar() async {
    if (await _gravador.isRecording()) {
      await _gravador.stop();
    }
  }

  Future<void> liberar() async {
    await descartar();
    await _gravador.dispose();
  }
}