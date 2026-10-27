import 'package:engin_app/core/dominio/entidades/obra.dart';
import 'package:engin_app/modulos/diario_obra/apresentacao/relatorios/gerador_pdf_rdo.dart';
import 'package:engin_app/modulos/diario_obra/dominio/entidades/diario_obra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeradorPdfRdo', () {
    final obra = Obra(
      id: 'o1',
      nome: 'Residencial Aurora',
      cliente: 'Construtora Horizonte',
      localizacao: 'Rua das Obras, 123',
      dataInicio: DateTime(2026, 1, 15),
    );

    final diario = DiarioObra(
      id: 'd1',
      obraId: 'o1',
      data: DateTime(2026, 10, 26),
      transcricaoRaw: 'Gravação do dia com acentuação çãõé.',
      clima: 'Ensolarado',
      efetivo: const [EfetivoItem(funcao: 'Operários', quantidade: 12)],
      materiais: const [
        MaterialItem(material: 'Cimento', quantidade: 20, unidade: 'saco'),
      ],
      ocorrencias: const ['Atraso na entrega do aço'],
      prazos: const ['Finalizar a laje até 30/10'],
    );

    test('gera um PDF válido com o cabeçalho do RDO', () async {
      final bytes = await GeradorPdfRdo().gerar(obra: obra, diario: diario);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('embarca fonte TTF (acento PT-BR não sai quebrado)', () async {
      final bytes = await GeradorPdfRdo().gerar(obra: obra, diario: diario);
      final conteudo = String.fromCharCodes(bytes);

      // FontFile2 = TrueType embutida; sem ela, a Helvetica padrão do
      // dart_pdf descarta acentos do português.
      expect(conteudo, contains('FontFile2'));
    });

    test('gera PDF mesmo sem categorias extraídas', () async {
      final minimo = DiarioObra(
        id: 'd2',
        obraId: 'o1',
        data: DateTime(2026, 10, 27),
        transcricaoRaw: 'Relatório simples.',
      );

      final bytes = await GeradorPdfRdo().gerar(obra: obra, diario: minimo);

      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}