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

  Future<Map<String, dynamic>?> porId(String id) async {
    final linhas =
        await _db.query('obras', where: 'id = ?', whereArgs: [id], limit: 1);
    return linhas.firstOrNull;
  }
}