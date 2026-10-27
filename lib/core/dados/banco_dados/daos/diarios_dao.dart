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
}