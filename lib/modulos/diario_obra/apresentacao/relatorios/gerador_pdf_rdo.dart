import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/dominio/entidades/obra.dart';
import '../../dominio/entidades/diario_obra.dart';

/// Montagem do Relatório Diário de Obra (RDO) em PDF (Etapa 1, itens 3-4).
class GeradorPdfRdo {
  // Roboto embarcado: a fonte padrão Helvetica do dart_pdf não cobre
  // todo o Unicode e perderia acentos do PT-BR (ç, ã, õ, é) no RDO.
  static pw.Font? _fonteBase;
  static pw.Font? _fonteNegrito;

  Future<ByteData> _carregarFonte(String caminho) async {
    try {
      return await rootBundle.load(caminho);
    } catch (_) {
      // Em teste de unidade o bundle de assets pode não estar disponível;
      // lê do disco (caminho relativo à raiz do projeto).
      final bytes = await File(caminho).readAsBytes();
      return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    }
  }

  Future<pw.ThemeData?> _carregarTema() async {
    try {
      _fonteBase ??=
          pw.Font.ttf(await _carregarFonte('assets/fonts/Roboto-Regular.ttf'));
      _fonteNegrito ??=
          pw.Font.ttf(await _carregarFonte('assets/fonts/Roboto-Bold.ttf'));
      return pw.ThemeData.withFont(base: _fonteBase!, bold: _fonteNegrito!);
    } catch (_) {
      // Fallback: fontes padrão do dart_pdf.
      return null;
    }
  }

  Future<Uint8List> gerar({
    required Obra obra,
    required DiarioObra diario,
  }) async {
    final doc = pw.Document(theme: await _carregarTema());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _cabecalho(obra, diario),
          pw.SizedBox(height: 16),
          if (diario.clima != null) ...[
            _secao('Clima'),
            pw.Text(diario.clima!),
            pw.SizedBox(height: 12),
          ],
          if (diario.efetivo.isNotEmpty) ...[
            _secao('Efetivo / Mão de Obra'),
            _tabela(
              ['Função', 'Quantidade'],
              diario.efetivo
                  .map((EfetivoItem e) => [e.funcao, '${e.quantidade}'])
                  .toList(),
            ),
            pw.SizedBox(height: 12),
          ],
          if (diario.materiais.isNotEmpty) ...[
            _secao('Materiais Utilizados'),
            _tabela(
              ['Material', 'Qtd.', 'Un.'],
              diario.materiais
                  .map((MaterialItem m) => [
                        m.material,
                        m.quantidade % 1 == 0
                            ? m.quantidade.toInt().toString()
                            : m.quantidade.toStringAsFixed(2),
                        m.unidade,
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 12),
          ],
          if (diario.ocorrencias.isNotEmpty) ...[
            _secao('Ocorrências'),
            ...diario.ocorrencias.map(
              (String o) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('• $o'),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (diario.prazos.isNotEmpty) ...[
            _secao('Prazos e Compromissos'),
            ...diario.prazos.map(
              (String o) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('• $o'),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          _secao('Transcrição Original (áudio do diário)'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              diario.transcricaoRaw,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Gerado por EnginApp em '
            '${_formatarData(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _cabecalho(Obra obra, DiarioObra diario) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'RELATÓRIO DIÁRIO DE OBRA (RDO)',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                _formatarData(diario.data),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(),
          pw.Text('Obra: ${obra.nome}', style: const pw.TextStyle(fontSize: 11)),
          if (obra.cliente != null && obra.cliente!.isNotEmpty)
            pw.Text('Cliente: ${obra.cliente}',
                style: const pw.TextStyle(fontSize: 10)),
          if (obra.localizacao != null && obra.localizacao!.isNotEmpty)
            pw.Text('Local: ${obra.localizacao}',
                style: const pw.TextStyle(fontSize: 10)),
        ],
      );

  pw.Widget _secao(String titulo) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          titulo.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange800,
          ),
        ),
      );

  pw.Widget _tabela(List<String> cabecalho, List<List<String>> linhas) =>
      pw.TableHelper.fromTextArray(
        headers: cabecalho,
        data: linhas,
        headerStyle: const pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignments: {
          for (var i = 0; i < cabecalho.length; i++) i: pw.Alignment.centerLeft,
        },
        border: pw.TableBorder.all(color: PdfColors.grey400),
      );

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}