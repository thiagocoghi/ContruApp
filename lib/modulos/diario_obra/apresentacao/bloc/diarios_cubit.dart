import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dominio/erros/falha_dominio.dart';
import '../../dominio/entidades/diario_obra.dart';
import '../../dominio/repositorios/diario_repositorio.dart';

enum StatusDiarios { carregando, vazio, pronto, erro }

class EstadoDiarios extends Equatable {
  const EstadoDiarios({required this.status, this.diarios = const [], this.erro});

  final StatusDiarios status;
  final List<DiarioObra> diarios;
  final String? erro;

  const EstadoDiarios.pronto(this.diarios)
      : status = StatusDiarios.pronto,
        erro = null;

  const EstadoDiarios.erro(String mensagem)
      : status = StatusDiarios.erro,
        diarios = const [],
        erro = mensagem;

  @override
  List<Object?> get props => [status, diarios, erro];
}

/// Estado da lista de RDOs de uma obra.
class DiariosCubit extends Cubit<EstadoDiarios> {
  DiariosCubit({required this.repositorio, required this.obraId})
      : super(const EstadoDiarios(status: StatusDiarios.carregando));

  final DiarioRepositorio repositorio;
  final String obraId;

  Future<void> carregar() async {
    emit(const EstadoDiarios(status: StatusDiarios.carregando));
    try {
      final diarios = await repositorio.listarPorObra(obraId);
      if (diarios.isEmpty) {
        emit(const EstadoDiarios(status: StatusDiarios.vazio));
      } else {
        emit(EstadoDiarios.pronto(diarios));
      }
    } on Exception catch (e) {
      emit(EstadoDiarios.erro(
        e is FalhaDominio ? e.mensagem : 'Erro ao carregar os diários.',
      ));
    }
  }

  /// Corrige a transcrição editada pelo engenheiro, mantendo os campos já
  /// extraídos (clima, efetivo, materiais...) como estão.
  Future<bool> atualizarTranscricao({
    required DiarioObra diario,
    required String texto,
  }) async {
    final limpo = texto.trim();
    if (limpo.isEmpty) {
      emit(const EstadoDiarios.erro('A transcrição não pode ficar vazia.'));
      return false;
    }
    try {
      await repositorio.atualizarTranscricao(id: diario.id, texto: limpo);
      await carregar();
      return true;
    } on Exception catch (e) {
      emit(EstadoDiarios.erro(
        e is FalhaDominio ? e.mensagem : 'Erro ao salvar a transcrição.',
      ));
      return false;
    }
  }

  /// Apaga o RDO e o PDF gerado a partir dele.
  Future<bool> excluir(DiarioObra diario) async {
    try {
      await repositorio.excluir(diario);
      await carregar();
      return true;
    } on Exception catch (e) {
      emit(EstadoDiarios.erro(
        e is FalhaDominio ? e.mensagem : 'Erro ao excluir o diário.',
      ));
      return false;
    }
  }
}