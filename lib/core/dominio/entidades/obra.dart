import 'package:equatable/equatable.dart';

/// Obra/empreendimento — entidade raiz compartilhada por todos os módulos.
class Obra extends Equatable {
  const Obra({
    required this.id,
    required this.nome,
    required this.dataInicio,
    this.cliente,
    this.localizacao,
  });

  final String id;
  final String nome;
  final String? cliente;
  final String? localizacao;
  final DateTime dataInicio;

  @override
  List<Object?> get props => [id, nome, cliente, localizacao, dataInicio];
}