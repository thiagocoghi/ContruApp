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

/// Repositório em memória para o smoke test (não usa SQLite nativo).
class _ObraRepositorioVazio implements ObraRepositorio {
  @override
  Future<List<Obra>> listar() async => const [];

  @override
  Future<List<Obra>> listarAtivas() async => const [];

  @override
  Future<List<Obra>> listarArquivadas() async => const [];

  @override
  Future<Obra?> porId(String id) async => null;

  @override
  Future<void> salvar(Obra obra) async {}

  @override
  Future<void> atualizar(Obra obra) async {}

  @override
  Future<void> excluir(String id) async {}
}

/// SLM falso que nunca fica pronto — o smoke test não pode baixar modelo.
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

void main() {
  testWidgets('BuildSapApp renderiza a tela inicial', (tester) async {
    final repositorio = _ObraRepositorioVazio();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ObrasCubit>(
            create: (_) => ObrasCubit(
              repositorio: repositorio,
              criarObra: CriarObra(repositorio),
              editarObra: EditarObra(repositorio),
              fecharObra: FecharObra(repositorio),
              reabrirObra: ReabrirObra(repositorio),
              alternarArquivamento: AlternarArquivamento(repositorio),
              excluirObra: ExcluirObra(repositorio),
            )..carregar(),
          ),
          // Sem iniciar(): o teste não dispara o download do modelo.
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

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('EnginApp'), findsOneWidget);
    expect(find.text('Nenhuma obra cadastrada'), findsOneWidget);
    // Sem download em andamento, o banner fica escondido.
    expect(find.text('Instalando a IA do canteiro'), findsNothing);
  });
}