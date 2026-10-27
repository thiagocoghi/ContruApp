import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dominio/casos_de_uso/criar_obra.dart';
import '../../../../core/dominio/entidades/obra.dart';
import '../../../../core/dominio/erros/falha_dominio.dart';
import '../../../../core/dominio/repositorios/obra_repositorio.dart';

enum StatusObras { carregando, vazio, pronto, erro }

class EstadoObras extends Equatable {
  const EstadoObras({required this.status, this.obras = const [], this.erro});

  final StatusObras status;
  final List<Obra> obras;
  final String? erro;

  const EstadoObras.pronto(this.obras)
      : status = StatusObras.pronto,
        erro = null;

  const EstadoObras.erro(String mensagem)
      : status = StatusObras.erro,
        obras = const [],
        erro = mensagem;

  @override
  List<Object?> get props => [status, obras, erro];
}

/// Estado da tela inicial (lista de obras).
class ObrasCubit extends Cubit<EstadoObras> {
  ObrasCubit({required this.repositorio, required this.criarObra})
      : super(const EstadoObras(status: StatusObras.carregando));

  final ObraRepositorio repositorio;
  final CriarObra criarObra;

  Future<void> carregar() async {
    emit(const EstadoObras(status: StatusObras.carregando));
    try {
      final obras = await repositorio.listar();
      if (obras.isEmpty) {
        emit(const EstadoObras(status: StatusObras.vazio));
      } else {
        emit(EstadoObras.pronto(obras));
      }
    } on Exception catch (e) {
      emit(EstadoObras.erro(_mensagem(e)));
    }
  }

  Future<bool> criar({
    required String nome,
    String? cliente,
    String? localizacao,
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
      );
      await carregar();
      return true;
    } on Exception catch (e) {
      emit(EstadoObras.erro(_mensagem(e)));
      return false;
    }
  }

  String _mensagem(Object e) =>
      e is FalhaDominio ? e.mensagem : 'Erro inesperado ao acessar o banco.';
}