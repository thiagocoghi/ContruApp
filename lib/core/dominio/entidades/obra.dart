import 'package:equatable/equatable.dart';

/// Ciclo de vida da obra — resolve o pedido de "fechar" e "arquivar" o item.
enum ObraStatus {
  /// Em andamento: aceita novos diários.
  ativa,

  /// Encerrada: tem data de fim preenchida e sai da lista principal, mas o
  /// histórico continua íntegro e legível.
  concluida,

  /// Arquivada: guardada em área própria, escondida do dia a dia.
  arquivada,
}

/// Obra/empreendimento — entidade raiz compartilhada por todos os módulos.
class Obra extends Equatable {
  const Obra({
    required this.id,
    required this.nome,
    required this.dataInicio,
    this.cliente,
    this.localizacao,
    this.detalhes,
    this.dataFim,
    this.status = ObraStatus.ativa,
  });

  final String id;
  final String nome;
  final String? cliente;
  final String? localizacao;

  /// Observações livres do engenheiro/mestre de obra.
  final String? detalhes;

  final DateTime dataInicio;

  /// Preenchida quando a obra é encerrada; nula enquanto estiver ativa.
  final DateTime? dataFim;

  final ObraStatus status;

  bool get estaAtiva => status == ObraStatus.ativa;

  /// Cópia com os campos informados trocados.
  ///
  /// [dataFim] usa `?? this.dataFim`, então passar `null` **mantém** o valor
  /// atual — para limpar o campo construa um [Obra] novo (caso `ReabrirObra`).
  Obra copiarCom({
    String? nome,
    String? cliente,
    String? localizacao,
    String? detalhes,
    DateTime? dataInicio,
    DateTime? dataFim,
    ObraStatus? status,
  }) =>
      Obra(
        id: id,
        nome: nome ?? this.nome,
        cliente: cliente ?? this.cliente,
        localizacao: localizacao ?? this.localizacao,
        detalhes: detalhes ?? this.detalhes,
        dataInicio: dataInicio ?? this.dataInicio,
        dataFim: dataFim ?? this.dataFim,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props =>
      [id, nome, cliente, localizacao, detalhes, dataInicio, dataFim, status];
}
