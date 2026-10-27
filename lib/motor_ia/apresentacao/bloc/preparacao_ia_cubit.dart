import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../orquestrador_ia.dart';

enum StatusIa { aguardando, baixando, carregando, pronto, erro }

class EstadoIa extends Equatable {
  const EstadoIa({required this.status, this.fracao, this.mensagem});

  final StatusIa status;

  /// Fração do download (0..1) — `null` enquanto o tamanho total é
  /// desconhecido (barra indeterminada).
  final double? fracao;

  final String? mensagem;

  const EstadoIa.baixando(this.fracao)
      : status = StatusIa.baixando,
        mensagem = null;

  const EstadoIa.carregando()
      : status = StatusIa.carregando,
        fracao = 1,
        mensagem = null;

  const EstadoIa.pronto()
      : status = StatusIa.pronto,
        fracao = 1,
        mensagem = null;

  const EstadoIa.erro(this.mensagem)
      : status = StatusIa.erro,
        fracao = null;

  @override
  List<Object?> get props => [status, fracao, mensagem];
}

/// Instala e configura a LLM do app (Qwen 2.5 1.5B) automaticamente.
///
/// Chamado na inicialização do app (`RegistrarDependencias.blocProviders`):
/// na primeira execução baixa o modelo (~1 GB) e o carrega; nas seguintes
/// encontra o cache e fica `pronto` em segundos, sem rede. Enquanto isso
/// acontece, a UI mostra o progresso pelo [EstadoIa] — e se falhar, o app
/// segue funcionando com as regras determinísticas (cascata do
/// `OrquestradorIa`).
class PreparacaoIaCubit extends Cubit<EstadoIa> {
  PreparacaoIaCubit({required this.orquestrador})
      : super(const EstadoIa(status: StatusIa.aguardando));

  final OrquestradorIa orquestrador;

  bool _emAndamento = false;

  /// A LLM já está instalada e em memória.
  bool get instalada => orquestrador.iaDisponivel;

  /// Inicia (ou retoma) a instalação. Idempotente: chamadas repetidas
  /// enquanto há download em andamento são ignoradas.
  Future<void> iniciar() async {
    if (_emAndamento) return;
    if (orquestrador.iaDisponivel) {
      emit(const EstadoIa.pronto());
      return;
    }

    _emAndamento = true;
    emit(const EstadoIa.baixando(null));
    try {
      await orquestrador.preparar(aoProgresso: _aoProgresso);
      if (isClosed) return;
      emit(const EstadoIa.pronto());
    } catch (erro) {
      if (isClosed) return;
      emit(EstadoIa.erro(_mensagem(erro)));
    } finally {
      _emAndamento = false;
    }
  }

  /// Reinicia a instalação após uma falha (botão "Tentar de novo").
  Future<void> tentarNovamente() => iniciar();

  void _aoProgresso(double? fracao) {
    if (isClosed) return;

    // Download concluído: o que vem agora é a carga em memória.
    if (fracao != null && fracao >= 1) {
      emit(const EstadoIa.carregando());
      return;
    }

    // Arredonda em 1% — o callback dispara dezenas de vezes por segundo e o
    // Cubit descarta estados iguais, mantendo a UI estável.
    final arredondado =
        fracao == null ? null : (fracao * 100).roundToDouble() / 100;
    emit(EstadoIa.baixando(arredondado));
  }

  String _mensagem(Object erro) {
    final texto = erro.toString();
    if (texto.contains('SocketException') ||
        texto.contains('HttpException') ||
        texto.contains('404') ||
        texto.contains('download')) {
      return 'Sem conexão ou download interrompido. '
          'Conecte-se à internet e tente de novo.';
    }
    return 'Não foi possível instalar a IA agora. '
        'A extração dos diários segue pelas regras.';
  }
}
