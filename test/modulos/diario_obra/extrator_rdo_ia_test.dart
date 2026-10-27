import 'package:engin_app/modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_ia.dart';
import 'package:engin_app/motor_ia/dominio/interfaces/inferencia_slm.dart';
import 'package:flutter_test/flutter_test.dart';

/// SLM falso: devolve a resposta ensaiada sem tocar no runtime nativo.
class _SlmFalso implements InferenciaSlm {
  _SlmFalso({this.resposta = ''});

  final String resposta;

  @override
  bool get pronto => true;

  int chamadas = 0;
  String? ultimaInstrucao;
  String? ultimaEntrada;
  int? ultimoMaxTokens;

  @override
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) async {}

  @override
  Future<String> completar({
    required String instrucao,
    required String entrada,
    int maxTokens = 384,
  }) async {
    chamadas++;
    ultimaInstrucao = instrucao;
    ultimaEntrada = entrada;
    ultimoMaxTokens = maxTokens;
    return resposta;
  }

  @override
  Future<void> liberar() async {}
}

const _jsonCompleto = '''
{
  "clima": "Nublado",
  "efetivo": [{"funcao": "Pedreiro", "quantidade": 8}],
  "materiais": [
    {"material": "Cimento", "quantidade": 15, "unidade": "saco"},
    {"material": "Tijolo", "quantidade": "300", "unidade": "unidade"}
  ],
  "ocorrencias": ["Atraso na entrega do aço"],
  "prazos": ["Entregar aço até amanhã"]
}''';

void main() {
  group('ExtratorRdoIa — parser da resposta do SLM', () {
    test('converte JSON direto no schema do RDO', () async {
      final extrator = ExtratorRdoIa(slm: _SlmFalso(resposta: _jsonCompleto));

      final extracao = await extrator.extrair('transcrição qualquer');

      expect(extracao.clima, 'Nublado');
      expect(extracao.efetivo.single.funcao, 'Pedreiro');
      expect(extracao.efetivo.single.quantidade, 8);
      expect(extracao.materiais, hasLength(2));
      expect(extracao.materiais.first.material, 'Cimento');
      expect(extracao.materiais.first.quantidade, 15);
      // Quantidade vem como texto do modelo e ainda assim é convertida.
      expect(extracao.materiais.last.quantidade, 300);
      expect(extracao.ocorrencias.single, 'Atraso na entrega do aço');
      expect(extracao.prazos.single, 'Entregar aço até amanhã');
    });

    test('ignora cercas de código e texto em volta do JSON', () async {
      final extrator = ExtratorRdoIa(
        slm: _SlmFalso(
          resposta: 'Aqui está o JSON:\n```json\n$_jsonCompleto\n```\n',
        ),
      );

      final extracao = await extrator.extrair('transcrição qualquer');

      expect(extracao.clima, 'Nublado');
      expect(extracao.materiais, hasLength(2));
    });

    test('tolera campos nulos, listas ausentes e valores malformados', () async {
      final extrator = ExtratorRdoIa(
        slm: _SlmFalso(
          resposta: '{"clima": null, "efetivo": [{"funcao": "Pintor", '
              '"quantidade": "muitos"}], "materiais": "n/a", '
              '"ocorrencias": [null, 42, "  "]}',
        ),
      );

      final extracao = await extrator.extrair('transcrição qualquer');

      expect(extracao.clima, isNull);
      expect(extracao.efetivo, isEmpty);
      expect(extracao.materiais, isEmpty);
      expect(extracao.ocorrencias, isEmpty);
      expect(extracao.prazos, isEmpty);
      expect(extracao.vazio, isTrue);
    });

    test('resposta sem JSON lança FormatException (fallback do orquestrador)',
        () async {
      final extrator = ExtratorRdoIa(
        slm: _SlmFalso(resposta: 'Desculpe, não posso ajudar com isso.'),
      );

      expect(
        () => extrator.extrair('transcrição qualquer'),
        throwsA(isA<FormatException>()),
      );
    });

    test('transcrição vazia não chega ao modelo', () async {
      final slm = _SlmFalso(resposta: _jsonCompleto);
      final extrator = ExtratorRdoIa(slm: slm);

      final extracao = await extrator.extrair('   ');

      expect(extracao.vazio, isTrue);
      expect(slm.chamadas, 0);
    });

    test('envia a transcrição como entrada e instrução de schema', () async {
      final slm = _SlmFalso(resposta: _jsonCompleto);
      final extrator = ExtratorRdoIa(slm: slm, maxTokens: 128);

      await extrator.extrair('8 pedreiros na obra');

      expect(slm.chamadas, 1);
      expect(slm.ultimaEntrada, '8 pedreiros na obra');
      expect(slm.ultimaInstrucao, contains('"materiais"'));
      expect(slm.ultimoMaxTokens, 128);
    });
  });
}
