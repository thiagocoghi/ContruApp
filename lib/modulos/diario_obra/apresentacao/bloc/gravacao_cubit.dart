import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dominio/erros/falha_dominio.dart';
import '../../dados/fontes_locais/gravador_audio.dart';
import '../../dominio/casos_de_uso/montar_diario_por_voz.dart';
import '../../dominio/entidades/diario_obra.dart';
import '../../dominio/repositorios/diario_repositorio.dart';

enum StatusGravacao { inicial, gravando, processando, pronto, erro }

class EstadoGravacao extends Equatable {
  const EstadoGravacao({
    required this.status,
    this.duracao = Duration.zero,
    this.diario,
    this.erro,
  });

  final StatusGravacao status;
  final Duration duracao;
  final DiarioObra? diario;
  final String? erro;

  const EstadoGravacao.gravando(this.duracao)
      : status = StatusGravacao.gravando,
        diario = null,
        erro = null;

  const EstadoGravacao.pronto(this.diario)
      : status = StatusGravacao.pronto,
        duracao = Duration.zero,
        erro = null;

  const EstadoGravacao.erro(String mensagem)
      : status = StatusGravacao.erro,
        duracao = Duration.zero,
        diario = null,
        erro = mensagem;

  @override
  List<Object?> get props => [status, duracao, diario, erro];
}

/// Fluxo do Diário de Obra por voz (Etapa 1):
/// gravar → transcrever (whisper local) → extrair entidades → salvar.
class GravacaoCubit extends Cubit<EstadoGravacao> {
  GravacaoCubit({
    required this.gravador,
    required this.montarDiario,
    required this.repositorio,
    required this.obraId,
  }) : super(const EstadoGravacao(status: StatusGravacao.inicial));

  final GravadorAudio gravador;
  final MontarDiarioPorVoz montarDiario;
  final DiarioRepositorio repositorio;
  final String obraId;

  Timer? _cronometro;
  String? _caminhoGravacao;

  /// Pede permissão e inicia a gravação.
  Future<void> iniciar() async {
    emit(const EstadoGravacao(status: StatusGravacao.inicial));
    try {
      final permitido = await gravador.temPermissao();
      if (!permitido) {
        emit(const EstadoGravacao.erro(
          'Permissão de microfone negada. Libere o microfone nos '
          'ajustes do app para gravar o diário.',
        ));
        return;
      }

      _caminhoGravacao = await gravador.caminhoNovo();
      await gravador.iniciar(caminhoDestino: _caminhoGravacao!);

      emit(const EstadoGravacao.gravando(Duration.zero));
      _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
        final atual = state;
        if (atual.status == StatusGravacao.gravando) {
          emit(EstadoGravacao.gravando(atual.duracao + const Duration(seconds: 1)));
        }
      });
    } on Exception catch (erro) {
      debugPrint('GravacaoCubit.iniciar falhou: $erro');
      emit(const EstadoGravacao.erro(
        'Não foi possível iniciar a gravação de áudio.',
      ));
    }
  }

  /// Para a gravação e roda o pipeline de transcrição + extração.
  Future<void> parar() async {
    _cronometro?.cancel();
    _cronometro = null;

    final caminho = await gravador.parar();
    emit(const EstadoGravacao(status: StatusGravacao.processando));

    try {
      final caminhoFinal = caminho ?? _caminhoGravacao;
      if (caminhoFinal == null) {
        emit(const EstadoGravacao.erro('Gravação perdida. Tente novamente.'));
        return;
      }
      final diario = await montarDiario.executar(
        caminhoAudio: caminhoFinal,
        obraId: obraId,
      );
      emit(EstadoGravacao.pronto(diario));
    } on FalhaDominio catch (e) {
      emit(EstadoGravacao.erro(e.mensagem));
    } on Exception catch (erro) {
      debugPrint('GravacaoCubit.parar falhou: $erro');
      emit(const EstadoGravacao.erro(
        'Falha na transcrição local. Verifique se o modelo de voz '
        'foi baixado e tente novamente.',
      ));
    }
  }

  /// Confirma o RDO e persiste no SQLite. Retorna true em sucesso.
  Future<bool> salvar() async {
    final diario = state.diario;
    if (diario == null) return false;
    try {
      await repositorio.salvar(diario);
      await _apagarGravacao();
      return true;
    } on Exception {
      emit(const EstadoGravacao.erro(
        'Erro ao salvar o diário no banco de dados.',
      ));
      return false;
    }
  }

  /// Descarta o resultado e volta ao estado inicial.
  Future<void> descartar() async {
    await _apagarGravacao();
    emit(const EstadoGravacao(status: StatusGravacao.inicial));
  }

  Future<void> _apagarGravacao() async {
    final caminho = _caminhoGravacao;
    if (caminho != null) {
      final arquivo = File(caminho);
      if (await arquivo.exists()) {
        await arquivo.delete();
      }
      _caminhoGravacao = null;
    }
  }

  @override
  Future<void> close() async {
    _cronometro?.cancel();
    await gravador.descartar();
    return super.close();
  }
}