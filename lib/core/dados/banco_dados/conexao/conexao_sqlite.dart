import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Conexão SQLite local (Seção 4 do PRD).
///
/// O app é offline-first: este é o único banco, não há backend.
class ConexaoSqlite {
  ConexaoSqlite._(this._db);

  final Database _db;
  Database get db => _db;

  /// Abre (ou cria) o banco com o schema inicial.
  ///
  /// [caminho] permite apontar para um arquivo de teste.
  static Future<ConexaoSqlite> abrir({String? caminho}) async {
    final caminhoBanco =
        caminho ?? p.join(await getDatabasesPath(), 'engin_app.db');
    final db = await openDatabase(
      caminhoBanco,
      version: 2,
      onCreate: criarSchema,
      onUpgrade: migrar,
    );
    return ConexaoSqlite._(db);
  }

  /// Schema inicial — Seção 4 do PRD (esquema simplificado).
  static Future<void> criarSchema(Database db, int versao) async {
    await db.execute('''
      CREATE TABLE obras (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        cliente TEXT,
        localizacao TEXT,
        data_inicio TEXT NOT NULL,
        data_fim TEXT,
        detalhes TEXT,
        status TEXT NOT NULL DEFAULT 'ativa'
      )
    ''');

    await db.execute('''
      CREATE TABLE diarios_obra (
        id TEXT PRIMARY KEY,
        obra_id TEXT NOT NULL REFERENCES obras(id),
        data TEXT NOT NULL,
        transcricao_raw TEXT,
        clima TEXT,
        efetivo_json TEXT,
        ocorrencias_json TEXT,
        materiais_json TEXT,
        prazos_json TEXT,
        pdf_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE materiais (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        unidade TEXT NOT NULL,
        quantidade_estoque REAL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_diarios_obra_data ON diarios_obra(obra_id, data DESC)',
    );
  }

  /// Migração v1 → v2: ciclo de vida da obra (data de fim, observações do
  /// engenheiro e status para fechar/arquivar o item).
  static Future<void> migrar(
    Database db,
    int versaoAntigo,
    int versaoNovo,
  ) async {
    if (versaoAntigo < 2) {
      for (final coluna in [
        'data_fim TEXT',
        'detalhes TEXT',
        "status TEXT NOT NULL DEFAULT 'ativa'",
      ]) {
        if (!await _temColuna(db, 'obras', coluna.split(' ').first)) {
          await db.execute('ALTER TABLE obras ADD COLUMN $coluna');
        }
      }
    }
  }

  static Future<bool> _temColuna(
    Database db,
    String tabela,
    String coluna,
  ) async {
    final linhas = await db.rawQuery('PRAGMA table_info($tabela)');
    return linhas.any((l) => l['name'] == coluna);
  }

  Future<void> fechar() => _db.close();
}
