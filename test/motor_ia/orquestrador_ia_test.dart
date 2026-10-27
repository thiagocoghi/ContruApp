import 'package:engin_app/modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_regras.dart';
import 'package:engin_app/motor_ia/dominio/interfaces/inferencia_slm.dart';
import 'package:engin_app/motor_ia/orquestrador_ia.dart';
import 'package:flutter_test/flutter_test.dart';

/// SLM falso controlável: pronto/ausente, resposta válida ou erro.
class _SlmFalso implements InferenciaSlm {
  _SlmFalso({this.pronto = true, this.resposta = '', this.erro});

  @override
  final bool pronto;

  String resposta;
  Object? erro;

  int chamadas = 0;
  int preparacoes = 0;
  int liberacoes = 0;

  @override
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) async {
    preparacoes++;
  }

  @override
  Future<String> completar({
    required String instrucao,
    required String entrada,
    int maxTokens = 384,
  }) async {
    chamadas++;
    final erro = this.erro;
    if (erro != null) throw erro;
    return resposta;
  }

  @override
  Future<void> liberar() async {
    liberacoes++;
  }
}

const _transcricao = 'Hoje trabalharam 8 pedreiros. '
    'Compramos 15 sacos de cimento. Estava nublado.';

const _jsonSaida = '''
{"clima": "Chuva",
 "efetivo": [{"funcao": "Pedreiro", "quantidade": 8}],
 "materiais": [{"material": "Cimento", "quantidade": 15, "unidade": "saco"}],
 "ocorrencias": ["Entrega de aço atrasada"], "prazos": []}''';

void main() {
  group('OrquestradorIa — cascata SLM → regras', () {
    test('sem modelo pronto usa as regras e nem toca no SLM', () async {
      final slm = _SlmFalso(pronto: false, resposta: _jsonSaida);
      final orquestrador = OrquestradorIa(slm: slm);

      final extracao = await orquestrador.extrair(_transcricao);

      expect(slm.chamadas, 0);
      expect(extracao.clima, 'Nublado');
      expect(extracao.ocorrencias, isEmpty);
      // Estado "não pronto" é delegado ao motor de inferência.
      expect(slm.pronto, isFalse);
    });

    test('com modelo pronto a resposta do SLM prevalece sobre as regras',
        () async {
      final slm = _SlmFalso(resposta: _jsonSaida);
      final orquestrador = OrquestradorIa(
        slm: slm,
        extratorRegras: const ExtratorRdoRegras(),
      );

      final extracao = await orquestrador.extrair(_transcricao);

      expect(slm.chamadas, 1);
      expect(extracao.clima, 'Chuva');
      expect(extracao.efetivo, hasLength(1));
      expect(extracao.ocorrencias, ['Entrega de aço atrasada']);
      // Com o motor pronto, a cascata passa pelo SLM (chamadas == 1 acima).
      expect(slm.pronto, isTrue);
    });

    test('erro de inferência cai para as regras em vez de quebrar o fluxo',
        () async {
      final slm = _SlmFalso(
        pronto: true,
        erro: StateError('runtime nativo indisponível'),
      );
      final orquestrador = OrquestradorIa(slm: slm);

      final extracao = await orquestrador.extrair(_transcricao);

      expect(extracao.clima, 'Nublado');
      expect(extracao.efetivo.single.quantidade, 8);
      expect(extracao.materiais.single.material.toLowerCase(), 'cimento');
    });

    test('resposta do SLM sem JSON cai para as regras', () async {
      final slm = _SlmFalso(
        pronto: true,
        resposta: 'Não consegui interpretar a transcrição.',
      );
      final orquestrador = OrquestradorIa(slm: slm);

      final extracao = await orquestrador.extrair(_transcricao);

      expect(extracao.clima, 'Nublado');
    });

    test('resposta JSON válida porém vazia cai para as regras', () async {
      final slm = _SlmFalso(
        pronto: true,
        resposta: '{"clima": null, "efetivo": [], "materiais": [],'
            ' "ocorrencias": [], "prazos": []}',
      );
      final orquestrador = OrquestradorIa(slm: slm);

      final extracao = await orquestrador.extrair(_transcricao);

      expect(extracao.vazio, isFalse);
      expect(extracao.clima, 'Nublado');
    });

    test('ciclo de vida é delegado ao SLM', () async {
      final slm = _SlmFalso();
      final orquestrador = OrquestradorIa(slm: slm);

      await orquestrador.preparar();
      await orquestrador.liberar();

      expect(slm.preparacoes, 1);
      expect(slm.liberacoes, 1);
    });
  });
}
