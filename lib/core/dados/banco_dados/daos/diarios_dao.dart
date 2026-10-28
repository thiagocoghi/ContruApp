import 'package:sqflite/sqflite.dart';

/// DAO da tabela `diarios_obra` (RDO).
class DiariosDao {
  DiariosDao(this._db);

  final Database _db;

  Future<void> inserir(Map<String, dynamic> linha) => _db.insert(
        'diarios_obra',
        linha,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Map<String, dynamic>>> listarPorObra(String obraId) => _db.query(
        'diarios_obra',
        where: 'obra_id = ?',
        whereArgs: [obraId],
        orderBy: 'data DESC',
      );

  Future<Map<String, dynamic>?> porId(String id) async {
    final linhas = await _db.query(
      'diarios_obra',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return linhas.firstOrNull;
  }

  Future<void> atualizarPdf(String id, String caminhoPdf) => _db.update(
        'diarios_obra',
        {'pdf_path': caminhoPdf},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Corrige só a transcrição — os demais campos extraídos ficam intactos.
  Future<void> atualizarTranscricao(String id, String texto) => _db.update(
        'diarios_obra',
        {'transcricao_raw': texto},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> excluir(String id) => _db.delete(
        'diarios_obra',
        where: 'id = ?',
        whereArgs: [id],
      );
}