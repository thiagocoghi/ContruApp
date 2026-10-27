import 'package:engin_app/modulos/diario_obra/dados/modelos/diario_obra_modelo.dart';
import 'package:engin_app/modulos/diario_obra/dominio/entidades/diario_obra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiarioObraModelo', () {
    final diario = DiarioObra(
      id: 'd1',
      obraId: 'o1',
      data: DateTime(2026, 10, 26, 8, 30),
      transcricaoRaw: 'Transcrição com acentuação: çãõé!', // gravação no banco
      clima: 'Chuva',
      efetivo: const [EfetivoItem(funcao: 'Pedreiros', quantidade: 6)],
      materiais: const [
        MaterialItem(material: 'Cimento', quantidade: 20, unidade: 'saco'),
      ],
      ocorrencias: const ['Atraso na entrega do aço'],
      prazos: const ['Finalizar a laje até 30/10'],
      pdfPath: '/docs/RDO_o1.pdf',
    );

    test('roundtrip preserva todos os campos', () {
      final mapa = DiarioObraModelo.paraMapa(diario);
      final volta = DiarioObraModelo.deMapa(mapa);

      expect(volta, diario);
      expect(volta.data, diario.data);
      expect(volta.transcricaoRaw, diario.transcricaoRaw);
    });

    test('mapeia as colunas do schema da Seção 4 do PRD', () {
      final mapa = DiarioObraModelo.paraMapa(diario);

      expect(mapa.keys, containsAll([
        'id',
        'obra_id',
        'data',
        'transcricao_raw',
        'clima',
        'efetivo_json',
        'ocorrencias_json',
        'pdf_path',
      ]));
      expect(mapa['obra_id'], 'o1');
      expect(mapa['efetivo_json'], isA<String>());
    });

    test('tolera linhas sem listas preenchidas (NULL no banco)', () {
      final volta = DiarioObraModelo.deMapa({
        'id': 'd2',
        'obra_id': 'o1',
        'data': '2026-10-26T08:30:00.000',
        'transcricao_raw': null,
        'clima': null,
      });

      expect(volta.transcricaoRaw, '');
      expect(volta.efetivo, isEmpty);
      expect(volta.materiais, isEmpty);
      expect(volta.ocorrencias, isEmpty);
      expect(volta.prazos, isEmpty);
      expect(volta.pdfPath, isNull);
    });
  });
}