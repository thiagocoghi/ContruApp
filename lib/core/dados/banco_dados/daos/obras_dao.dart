import 'package:sqflite/sqflite.dart';

/// DAO da tabela `obras`.
class ObrasDao {
  ObrasDao(this._db);

  final Database _db;

  Future<void> inserir(Map<String, dynamic> linha) => _db.insert(
        'obras',
        linha,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Map<String, dynamic>>> listar() =>
      _db.query('obras', orderBy: 'data_inicio DESC');

  Future<List<Map<String, dynamic>>> listarPorStatus(List<String> statuses) =>
      _db.query(
        'obras',
        where: List.filled(statuses.length, 'status = ?').join(' OR '),
        whereArgs: statuses,
        orderBy: 'data_inicio DESC',
      );

  Future<Map<String, dynamic>?> porId(String id) async {
    final linhas =
        await _db.query('obras', where: 'id = ?', whereArgs: [id], limit: 1);
    return linhas.firstOrNull;
  }

  Future<void> atualizar(Map<String, dynamic> linha) => _db.update(
        'obras',
        linha,
        where: 'id = ?',
        whereArgs: [linha['id']],
      );

  /// Exclusão em cascata dentro de uma transação: a obra some junto com os
  /// diários, os PDFs e o índice deles — sem deixar órfão.
  Future<void> excluirComDiarios(String id) => _db.transaction((txn) async {
        await txn.delete('diarios_obra', where: 'obra_id = ?', whereArgs: [id]);
        await txn.delete('obras', where: 'id = ?', whereArgs: [id]);
      });
}