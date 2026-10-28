import 'dart:io';

import 'package:engin_app/core/dados/banco_dados/conexao/conexao_sqlite.dart';
import 'package:engin_app/core/dados/banco_dados/daos/obras_dao.dart';
import 'package:engin_app/core/dados/repositorios/obra_repositorio_sqlite.dart';
import 'package:engin_app/core/dominio/casos_de_uso/criar_obra.dart';
import 'package:engin_app/core/dominio/entidades/obra.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Banco em arquivo temporário: o app do usuário já está na v1 e a migração
/// precisa funcionar em cima de dados reais, não só em banco novo.
void main() {
  late Directory pasta;
  late String caminho;

  setUpAll(() {
    // Sem celular emulado, o `openDatabase` do sqflite precisa do backend
    // FFI — é ele que dá vida ao SQLite de verdade nestes testes.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('enginapp_teste');
    caminho = p.join(pasta.path, 'engin_app.db');
    await _criarBancoV1(caminho);
  });

  tearDown(() async {
    if (await pasta.exists()) await pasta.delete(recursive: true);
  });

  ObraRepositorioSqlite repositorio(ConexaoSqlite conexao) =>
      ObraRepositorioSqlite(_daoDa(conexao));

  group('Migração v1 → v2', () {
    test('acrescenta as colunas novas sem perder a obra existente', () async {
      final conexao = await ConexaoSqlite.abrir(caminho: caminho);
      final repo = repositorio(conexao);

      final obras = await repo.listar();

      expect(obras, hasLength(1), reason: 'a obra da v1 sobrevive à migração');
      final obra = obras.single;
      expect(obra.nome, 'Obra Antiga');
      expect(obra.status, ObraStatus.ativa,
          reason: 'linha migrada sem status vira ativa');
      expect(obra.dataFim, isNull);
      expect(obra.detalhes, isNull);

      await conexao.fechar();
    });

    test('aceita salvar e editar as colunas novas depois da migração',
        () async {
      final conexao = await ConexaoSqlite.abrir(caminho: caminho);
      final repo = repositorio(conexao);
      final obra = (await repo.listar()).single;

      final editada = obra.copiarCom(
        detalhes: 'Combinado com o mestre: fundação até sexta.',
      );
      await repo.atualizar(editada);

      final relida = await repo.porId(obra.id);
      expect(relida?.detalhes, 'Combinado com o mestre: fundação até sexta.');

      await conexao.fechar();
    });
  });

  group('Ciclo de vida da obra', () {
    test('FecharObra grava data de fim e sai das ativas', () async {
      final conexao = await ConexaoSqlite.abrir(caminho: caminho);
      final repo = repositorio(conexao);
      final obra = (await repo.listar()).single;

      final fim = DateTime(2026, 11, 30);
      await FecharObra(repo).executar(obra: obra, dataFim: fim);

      expect(await repo.listarAtivas(), isEmpty);
      expect(await repo.listarArquivadas(), hasLength(1));

      final encerrada = await repo.porId(obra.id);
      expect(encerrada?.status, ObraStatus.concluida);
      expect(encerrada?.dataFim, fim);

      await conexao.fechar();
    });

    test('ReabrirObra limpa a data de fim e volta para a lista principal',
        () async {
      final conexao = await ConexaoSqlite.abrir(caminho: caminho);
      final repo = repositorio(conexao);
      final obra = (await repo.listar()).single;

      await FecharObra(repo).executar(obra: obra);
      final encerrada = await repo.porId(obra.id);
      await ReabrirObra(repo).executar(obra: encerrada!);

      final reaberta = await repo.porId(obra.id);
      expect(reaberta?.status, ObraStatus.ativa);
      expect(reaberta?.dataFim, isNull,
          reason: 'reabrir tem que limpar a data, não só mudar o status');
      expect(await repo.listarAtivas(), hasLength(1));

      await conexao.fechar();
    });

    test('Arquivar esconde da lista principal e volta ao desarquivar',
        () async {
      final conexao = await ConexaoSqlite.abrir(caminho: caminho);
      final repo = repositorio(conexao);
      final obra = (await repo.listar()).single;

      await AlternarArquivamento(repo).executar(obra: obra);
      expect(await repo.listarAtivas(), isEmpty);
      expect(await repo.listarArquivadas(), hasLength(1));

      final guardada = await repo.porId(obra.id);
      await AlternarArquivamento(repo).executar(obra: guardada!);
      expect(await repo.listarAtivas(), hasLength(1));

      await conexao.fechar();
    });
  });

  group('Exclusão em cascata', () {
    test('apaga a obra junto com todos os diários dela', () async {
      final conexao = await ConexaoSqlite.abrir(caminho: caminho);
      final repo = repositorio(conexao);
      final obra = (await repo.listar()).single;

      // Dois diários desta obra e um de outra, para garantir que a exclusão
      // não vaza para registros de terceiros.
      await conexao.db.insert('obras', {
        'id': 'outra',
        'nome': 'Outra obra',
        'data_inicio': DateTime(2026).toIso8601String(),
        'status': 'ativa',
      });
      for (final id in ['d1', 'd2']) {
        await conexao.db.insert('diarios_obra', {
          'id': id,
          'obra_id': obra.id,
          'data': DateTime(2026, 10, 27).toIso8601String(),
          'pdf_path': '/tmp/$id.pdf',
        });
      }
      await conexao.db.insert('diarios_obra', {
        'id': 'd3',
        'obra_id': 'outra',
        'data': DateTime(2026, 10, 27).toIso8601String(),
      });

      await ExcluirObra(repo).executar(obraId: obra.id);

      expect(await repo.porId(obra.id), isNull);
      final diariosRestantes =
          await conexao.db.query('diarios_obra', where: 'obra_id = ?', whereArgs: [obra.id]);
      expect(diariosRestantes, isEmpty,
          reason: 'diários órfãos ficariam apontando para obra inexistente');

      // O diário da outra obra permanece intacto.
      final daOutra = await conexao.db
          .query('diarios_obra', where: 'obra_id = ?', whereArgs: ['outra']);
      expect(daOutra, hasLength(1));
      expect(await repo.listarAtivas(), hasLength(1));

      await conexao.fechar();
    });
  });
}

ObrasDao _daoDa(ConexaoSqlite conexao) => ObrasDao(conexao.db);

/// Reproduz o banco como ele estava na versão 1: sem `data_fim`, `detalhes`
/// nem `status`.
Future<void> _criarBancoV1(String caminho) async {
  final db = await databaseFactoryFfi.openDatabase(
    caminho,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE obras (
            id TEXT PRIMARY KEY,
            nome TEXT NOT NULL,
            cliente TEXT,
            localizacao TEXT,
            data_inicio TEXT NOT NULL
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
        await db.execute(
          'CREATE INDEX idx_diarios_obra_data ON diarios_obra(obra_id, data DESC)',
        );
      },
    ),
  );
  await db.insert('obras', {
    'id': 'obra1',
    'nome': 'Obra Antiga',
    'cliente': 'Construtora X',
    'data_inicio': DateTime(2025, 1, 15).toIso8601String(),
  });
  await db.close();
}
