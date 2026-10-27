// Smoke test de inferência — Qwen 2.5 1.5B on-device.
//
// Valida o caminho real ponta a ponta sem tocar no Flutter:
// download/cache do modelo → llama.cpp → prompt do RDO → JSON → ExtracaoRdo.
//
//   dart run native/scripts/teste_inferencia.dart                  # fonte hf:// (baixa ~1 GB)
//   dart run native/scripts/teste_inferencia.dart caminho/local.gguf
//
// Com o modelo já baixado por `native/scripts/baixar_modelo_qwen.sh`, o
// caminho local é detectado automaticamente e nenhum download acontece.
import 'dart:io';

import 'package:engin_app/modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_ia.dart';
import 'package:engin_app/motor_ia/dados/slm/engine_qwen.dart';

const _transcricaoExemplo =
    'Hoje trabalharam 8 pedreiros e 2 eletricistas. '
    'Compramos 15 sacos de cimento e 300 tijolos. '
    'Choveu de manhã e a entrega do aço atrasou para amanhã.';

Future<void> main(List<String> argumentos) async {
  final local = File(
    'assets/modelos/slm/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
  );
  final fonte = argumentos.isNotEmpty
      ? argumentos.first
      : (local.existsSync() ? local.path : EngineQwen.fontePadrao);

  stdout.writeln('Fonte do modelo: $fonte');

  final motor = EngineQwen(fonte: fonte);
  final cronometro = Stopwatch()..start();

  try {
    var ultimoPercentual = -1;
    await motor.preparar(aoProgresso: (fracao) {
      if (fracao == null) return;
      // Progresso em passos de 1% — o callback dispara dezenas de vezes por
      // segundo e inundaria o console.
      final percentual = (fracao * 100).round();
      if (percentual == ultimoPercentual) return;
      ultimoPercentual = percentual;
      stdout.writeln('  download $percentual%');
    });
    stdout.writeln(
      'Modelo carregado em ${(cronometro.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );

    final extrator = ExtratorRdoIa(slm: motor);
    final extracao = await extrator.extrair(_transcricaoExemplo);
    cronometro.stop();

    stdout.writeln('\n--- ExtracaoRdo (${cronometro.elapsedMilliseconds} ms) ---');
    stdout.writeln('clima:        ${extracao.clima}');
    stdout.writeln(
      'efetivo:      ${extracao.efetivo.map((e) => '${e.quantidade}x ${e.funcao}').join(', ')}',
    );
    stdout.writeln(
      'materiais:    ${extracao.materiais.map((m) => '${m.quantidade} ${m.unidade} de ${m.material}').join(', ')}',
    );
    stdout.writeln('ocorrencias:  ${extracao.ocorrencias}');
    stdout.writeln('prazos:       ${extracao.prazos}');

    if (extracao.vazio) {
      stderr.writeln('\nFALHOU: o modelo não extraiu nenhuma entidade.');
      exitCode = 1;
    } else {
      stdout.writeln('\nOK: inferência on-device funcionando.');
    }
  } on Exception catch (erro) {
    stderr.writeln('\nFALHOU: $erro');
    exitCode = 1;
  } finally {
    await motor.liberar();
  }
}
