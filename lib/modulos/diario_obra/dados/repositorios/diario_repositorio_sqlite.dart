import 'dart:io';

import '../../../../core/dados/banco_dados/daos/diarios_dao.dart';
import '../../dominio/entidades/diario_obra.dart';
import '../../dominio/repositorios/diario_repositorio.dart';
import '../modelos/diario_obra_modelo.dart';

/// Implementação SQLite do repositório de Diários de Obra.
class DiarioRepositorioSqlite implements DiarioRepositorio {
  DiarioRepositorioSqlite(this._dao);

  final DiariosDao _dao;

  @override
  Future<List<DiarioObra>> listarPorObra(String obraId) async {
    final linhas = await _dao.listarPorObra(obraId);
    return linhas.map(DiarioObraModelo.deMapa).toList();
  }

  @override
  Future<DiarioObra?> porId(String id) async {
    final linha = await _dao.porId(id);
    return linha == null ? null : DiarioObraModelo.deMapa(linha);
  }

  @override
  Future<void> salvar(DiarioObra diario) =>
      _dao.inserir(DiarioObraModelo.paraMapa(diario));

  @override
  Future<void> registrarPdf({required String id, required String caminhoPdf}) =>
      _dao.atualizarPdf(id, caminhoPdf);

  @override
  Future<void> atualizarTranscricao({
    required String id,
    required String texto,
  }) =>
      _dao.atualizarTranscricao(id, texto);

  @override
  Future<void> excluir(DiarioObra diario) async {
    final caminhoPdf = diario.pdfPath;
    await _dao.excluir(diario.id);

    // O PDF é artefato gerado a partir do RDO: apagado o relatório, some
    // também. Arquivo já inexistente não deve derrubar a exclusão.
    if (caminhoPdf != null) {
      final arquivo = File(caminhoPdf);
      if (await arquivo.exists()) {
        try {
          await arquivo.delete();
        } on FileSystemException {
          // O registro já saiu do banco; um PDF órfão não é motivo para
          // falhar a operação que o usuário pediu.
        }
      }
    }
  }
}