import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/dominio/entidades/obra.dart';
import '../../dominio/entidades/diario_obra.dart';
import '../../dominio/repositorios/diario_repositorio.dart';
import 'gerador_pdf_rdo.dart';

/// Gera o PDF do RDO, salva no armazenamento do app e registra o caminho
/// no banco. O compartilhamento (WhatsApp/e-mail) é disparado pela UI com
/// o caminho retornado.
class ExportarRdoPdf {
  ExportarRdoPdf({
    required this.gerador,
    required this.diarios,
  });

  final GeradorPdfRdo gerador;
  final DiarioRepositorio diarios;

  Future<String> executar({
    required Obra obra,
    required DiarioObra diario,
  }) async {
    final bytes = await gerador.gerar(obra: obra, diario: diario);

    final diretorio = await getApplicationDocumentsDirectory();
    final nomeArquivo = 'RDO_${_limpar(obra.nome)}_${_data(diario.data)}.pdf';
    final arquivo = File(p.join(diretorio.path, nomeArquivo));

    await arquivo.writeAsBytes(bytes, flush: true);
    await diarios.registrarPdf(id: diario.id, caminhoPdf: arquivo.path);

    return arquivo.path;
  }

  String _limpar(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  String _data(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
}