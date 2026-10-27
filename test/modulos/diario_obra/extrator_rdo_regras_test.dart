import 'package:engin_app/modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_regras.dart';
import 'package:engin_app/modulos/diario_obra/dominio/entidades/diario_obra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extrator = ExtratorRdoRegras();

  group('ExtratorRdoRegras — extração completa', () {
    const texto = 'Hoje trabalharam 12 operários e 3 ajudantes no canteiro. '
        'Compramos 20 sacos de cimento e 500 tijolos. '
        'Estava ensolado e quente. '
        'Houve atraso na entrega do aço. '
        'O prazo da laje é até sexta-feira.';

    test('extrai as 5 categorias do RDO', () {
      final r = extrator.extrair(texto);

      expect(r.clima, 'Ensolarado');

      expect(
        r.efetivo,
        contains(const EfetivoItem(funcao: 'Operários', quantidade: 12)),
      );
      expect(
        r.efetivo,
        contains(const EfetivoItem(funcao: 'Ajudantes', quantidade: 3)),
      );

      expect(
        r.materiais,
        contains(
          const MaterialItem(material: 'Cimento', quantidade: 20, unidade: 'saco'),
        ),
      );
      expect(
        r.materiais,
        contains(
          const MaterialItem(
            material: 'Tijolo',
            quantidade: 500,
            unidade: 'unidade',
          ),
        ),
      );

      expect(r.ocorrencias, hasLength(1));
      expect(r.ocorrencias.single, contains('atraso'));

      // A frase de entrega (S4) vem antes da de prazo (S5).
      expect(r.prazos, hasLength(2));
      expect(r.prazos.first, contains('entrega do aço'));
      expect(r.prazos.last, contains('prazo da laje'));
      expect(r.vazio, isFalse);
    });

    test('materiais com unidade fracionada e vírgula decimal', () {
      final r = extrator.extrair('Foram usados 2,5 m³ de concreto na laje.');

      expect(r.materiais, hasLength(1));
      final m = r.materiais.single;
      expect(m.material.toLowerCase(), contains('concreto'));
      expect(m.quantidade, 2.5);
      expect(m.unidade, 'm³');
    });

    test('acumula quantidades da mesma função', () {
      final r = extrator.extrair(
        'Manhã: 4 pedreiros. Tarde: 6 pedreiros no canteiro.',
      );

      expect(r.efetivo, hasLength(1));
      expect(r.efetivo.single.funcao, 'Pedreiros');
      expect(r.efetivo.single.quantidade, 10);
    });
  });

  group('ExtratorRdoRegras — negações', () {
    test('não vira ocorrência nem clima negado', () {
      final r = extrator.extrair(
        'Estava nublado, sem chuva o dia todo. Não houve atraso na obra.',
      );

      expect(r.clima, 'Nublado');
      expect(r.ocorrencias, isEmpty);
    });

    test('"sem problema" não é ocorrência', () {
      final r = extrator.extrair('A equipe trabalhou bem, sem problema algum.');
      expect(r.ocorrencias, isEmpty);
    });
  });

  group('ExtratorRdoRegras — casos limites', () {
    test('texto vazio retorna extração vazia', () {
      final r = extrator.extrair('');
      expect(r.vazio, isTrue);
    });

    test('texto sem entidades conhecidas é vazio', () {
      final r = extrator.extrair('Bom dia a todos.');
      expect(r.vazio, isTrue);
    });
  });
}