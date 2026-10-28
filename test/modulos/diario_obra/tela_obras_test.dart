import 'package:engin_app/app/app.dart';
import 'package:engin_app/core/dominio/casos_de_uso/criar_obra.dart';
import 'package:engin_app/core/dominio/entidades/obra.dart';
import 'package:engin_app/core/dominio/repositorios/obra_repositorio.dart';
import 'package:engin_app/modulos/diario_obra/apresentacao/bloc/obras_cubit.dart';
import 'package:engin_app/motor_ia/apresentacao/bloc/preparacao_ia_cubit.dart';
import 'package:engin_app/motor_ia/dominio/interfaces/inferencia_slm.dart';
import 'package:engin_app/motor_ia/orquestrador_ia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório em memória: guarda as obras como estão, sem SQLite, para
/// exercitar a tela de obras do jeito que o usuário a usa.
class _RepositorioMemoria implements ObraRepositorio {
  final List<Obra> obras;

  _RepositorioMemoria(this.obras);

  @override
  Future<List<Obra>> listar() async => obras;

  @override
  Future<List<Obra>> listarAtivas() async =>
      obras.where((o) => o.estaAtiva).toList();

  @override
  Future<List<Obra>> listarArquivadas() async =>
      obras.where((o) => !o.estaAtiva).toList();

  @override
  Future<Obra?> porId(String id) async {
    for (final o in obras) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<void> salvar(Obra obra) async => obras.add(obra);

  @override
  Future<void> atualizar(Obra obra) async {
    final i = obras.indexWhere((o) => o.id == obra.id);
    if (i >= 0) obras[i] = obra;
  }

  @override
  Future<void> excluir(String id) async => obras.removeWhere((o) => o.id == id);
}

/// SLM falso que nunca fica pronto — o teste não pode baixar modelo.
class _SlmNulo implements InferenciaSlm {
  @override
  bool get pronto => false;

  @override
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) async {}

  @override
  Future<String> completar({
    required String instrucao,
    required String entrada,
    int maxTokens = 384,
  }) async =>
      '';

  @override
  Future<void> liberar() async {}
}

Obra _obra() => Obra(
      id: 'o1',
      nome: 'Residencial Aurora',
      cliente: 'Construtora X',
      localizacao: 'Rua das Obras, 100',
      dataInicio: DateTime(2026, 1, 15),
    );

Future<void> _montar(WidgetTester tester, _RepositorioMemoria repo) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ObrasCubit>(
          create: (_) => ObrasCubit(
            repositorio: repo,
            criarObra: CriarObra(repo),
            editarObra: EditarObra(repo),
            fecharObra: FecharObra(repo),
            reabrirObra: ReabrirObra(repo),
            alternarArquivamento: AlternarArquivamento(repo),
            excluirObra: ExcluirObra(repo),
          )..carregar(),
        ),
        BlocProvider<PreparacaoIaCubit>(
          create: (_) => PreparacaoIaCubit(
            orquestrador: OrquestradorIa(slm: _SlmNulo()),
          ),
        ),
      ],
      child: const BuildSapApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre o menu de contexto (os três pontos) da obra listada.
Future<void> _abrirMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista a obra ativa com cliente, local e datas', (tester) async {
    final repo = _RepositorioMemoria([_obra()]);
    await _montar(tester, repo);

    expect(find.text('Residencial Aurora'), findsOneWidget);
    expect(find.textContaining('Cliente: Construtora X'), findsOneWidget);
    expect(find.textContaining('Início: 15/01/2026'), findsOneWidget);
    expect(find.textContaining('ENCERRADAS E ARQUIVADAS'), findsNothing);
  });

  testWidgets('encerrar a obra tira da lista principal e vai para o rodapé',
      (tester) async {
    final repo = _RepositorioMemoria([_obra()]);
    await _montar(tester, repo);

    await _abrirMenu(tester);
    expect(find.text('Encerrar obra'), findsOneWidget);

    await tester.tap(find.text('Encerrar obra'));
    await tester.pumpAndSettle();

    // Diálogo de confirmação com a data de fim editável.
    expect(find.text('Encerrar a obra?'), findsOneWidget);
    await tester.tap(find.text('Encerrar').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('ENCERRADAS E ARQUIVADAS'), findsOneWidget);
    expect(await repo.listarAtivas(), isEmpty);
    expect((await repo.listar()).single.status, ObraStatus.concluida);
    expect((await repo.listar()).single.dataFim, isNotNull);
  });

  testWidgets('reabrir devolve a obra para a lista principal', (tester) async {
    final repo = _RepositorioMemoria([_obra()]);
    await _montar(tester, repo);

    await _abrirMenu(tester);
    await tester.tap(find.text('Encerrar obra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encerrar').last);
    await tester.pumpAndSettle();

    // Menu da obra já encerrada oferece reabrir, não encerrar.
    await _abrirMenu(tester);
    expect(find.text('Reabrir obra'), findsOneWidget);
    expect(find.text('Encerrar obra'), findsNothing);

    await tester.tap(find.text('Reabrir obra'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ENCERRADAS E ARQUIVADAS'), findsNothing);
    expect((await repo.listar()).single.status, ObraStatus.ativa);
    expect((await repo.listar()).single.dataFim, isNull,
        reason: 'reabrir tem que limpar a data de fim');
  });

  testWidgets('arquivar move a obra para a área de arquivo', (tester) async {
    final repo = _RepositorioMemoria([_obra()]);
    await _montar(tester, repo);

    await _abrirMenu(tester);
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ENCERRADAS E ARQUIVADAS'), findsOneWidget);
    expect(await repo.listarAtivas(), isEmpty);
    expect((await repo.listar()).single.status, ObraStatus.arquivada);
  });

  testWidgets('editar abre o formulário já preenchido com os dados atuais',
      (tester) async {
    final repo = _RepositorioMemoria([_obra()]);
    await _montar(tester, repo);

    await _abrirMenu(tester);
    await tester.tap(find.text('Editar dados e observações'));
    await tester.pumpAndSettle();

    expect(find.text('Editar obra'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Residencial Aurora'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Construtora X'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Rua das Obras, 100'),
        findsOneWidget);

    // O campo de observações do engenheiro existe e aceita anotação.
    expect(find.text('Observações'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Residencial Aurora'),
      'Residencial Aurora — Blocos A e B',
    );
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect((await repo.listar()).single.nome,
        'Residencial Aurora — Blocos A e B');
  });

  testWidgets('excluir exige digitar o nome da obra para confirmar',
      (tester) async {
    final repo = _RepositorioMemoria([_obra()]);
    await _montar(tester, repo);

    await _abrirMenu(tester);
    await tester.tap(find.text('Excluir obra e histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir esta obra?'), findsOneWidget);

    // Nome errado: a exclusão não acontece.
    await tester.enterText(find.byType(TextField), 'Outra obra');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(await repo.listar(), hasLength(1));

    // Nome certo: apaga de verdade.
    await _abrirMenu(tester);
    await tester.tap(find.text('Excluir obra e histórico'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Residencial Aurora');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(await repo.listar(), isEmpty);
    expect(find.text('Nenhuma obra cadastrada'), findsOneWidget);
  });
}