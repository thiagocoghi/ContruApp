import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dominio/casos_de_uso/criar_obra.dart';
import '../../../../core/dominio/entidades/obra.dart';
import '../../../../core/dominio/erros/falha_dominio.dart';
import '../../../../core/dominio/repositorios/obra_repositorio.dart';

enum StatusObras { carregando, vazio, pronto, erro }

class EstadoObras extends Equatable {
  const EstadoObras({
    required this.status,
    this.obras = const [],
    this.arquivadas = const [],
    this.erro,
  });

  final StatusObras status;
  final List<Obra> obras;
  final List<Obra> arquivadas;
  final String? erro;

  const EstadoObras.pronto(this.obras, {this.arquivadas = const []})
      : status = StatusObras.pronto,
        erro = null;

  const EstadoObras.erro(String mensagem)
      : status = StatusObras.erro,
        obras = const [],
        arquivadas = const [],
        erro = mensagem;

  @override
  List<Object?> get props => [status, obras, arquivadas, erro];
}

/// Estado da tela inicial (lista de obras).
class ObrasCubit extends Cubit<EstadoObras> {
  ObrasCubit({
    required this.repositorio,
    required this.criarObra,
    required this.editarObra,
    required this.fecharObra,
    required this.reabrirObra,
    required this.alternarArquivamento,
    required this.excluirObra,
  }) : super(const EstadoObras(status: StatusObras.carregando));

  final ObraRepositorio repositorio;
  final CriarObra criarObra;
  final EditarObra editarObra;
  final FecharObra fecharObra;
  final ReabrirObra reabrirObra;
  final AlternarArquivamento alternarArquivamento;
  final ExcluirObra excluirObra;

  Future<void> carregar() async {
    emit(const EstadoObras(status: StatusObras.carregando));
    try {
      final ativas = await repositorio.listarAtivas();
      final guardadas = await repositorio.listarArquivadas();
      if (ativas.isEmpty && guardadas.isEmpty) {
        emit(const EstadoObras(status: StatusObras.vazio));
      } else {
        emit(EstadoObras.pronto(ativas, arquivadas: guardadas));
      }
    } on Exception catch (e) {
      emit(EstadoObras.erro(_mensagem(e)));
    }
  }

  Future<bool> criar({
    required String nome,
    String? cliente,
    String? localizacao,
    String? detalhes,
    DateTime? dataInicio,
  }) async {
    if (nome.trim().isEmpty) {
      emit(const EstadoObras.erro('Informe o nome da obra.'));
      return false;
    }
    try {
      await criarObra.executar(
        nome: nome,
        cliente: cliente,
        localizacao: localizacao,
        detalhes: detalhes,
        dataInicio: dataInicio,
      );
      await carregar();
      return true;
    } on Exception catch (e) {
      emit(EstadoObras.erro(_mensagem(e)));
      return false;
    }
  }

  Future<bool> editar({
    required Obra obra,
    required String nome,
    String? cliente,
    String? localizacao,
    String? detalhes,
    required DateTime dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      await editarObra.executar(
        obra: obra,
        nome: nome,
        cliente: cliente,
        localizacao: localizacao,
        detalhes: detalhes,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );
      await carregar();
      return true;
    } on Exception catch (e) {
      emit(EstadoObras.erro(_mensagem(e)));
      return false;
    }
  }

  Future<void> fechar({required Obra obra, DateTime? dataFim}) async {
    await _eExecutar(() => fecharObra.executar(obra: obra, dataFim: dataFim));
  }

  Future<void> reabrir({required Obra obra}) =>
      _eExecutar(() => reabrirObra.executar(obra: obra));

  Future<void> alternarArquivo({required Obra obra}) =>
      _eExecutar(() => alternarArquivamento.executar(obra: obra));

  Future<void> excluir({required Obra obra}) => _eExecutar(
        () => excluirObra.executar(obraId: obra.id),
      );

  Future<void> _eExecutar(Future<void> Function() acao) async {
    try {
      await acao();
      await carregar();
    } on Exception catch (e) {
      emit(EstadoObras.erro(_mensagem(e)));
    }
  }

  String _mensagem(Object e) =>
      e is FalhaDominio ? e.mensagem : 'Erro inesperado ao acessar o banco.';
}