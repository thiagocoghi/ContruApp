import 'package:equatable/equatable.dart';

import 'diario_obra.dart';

/// Resultado estruturado da extração de entidades a partir do texto bruto
/// da transcrição (Etapa 1, funcionalidade 2 do PRD).
class ExtracaoRdo extends Equatable {
  const ExtracaoRdo({
    this.clima,
    this.efetivo = const [],
    this.materiais = const [],
    this.ocorrencias = const [],
    this.prazos = const [],
  });

  final String? clima;
  final List<EfetivoItem> efetivo;
  final List<MaterialItem> materiais;
  final List<String> ocorrencias;
  final List<String> prazos;

  /// Nenhuma entidade reconhecida — sinaliza que a transcrição pode ter
  /// vindo vazia ou com áudio sem fala útil.
  bool get vazio =>
      clima == null &&
      efetivo.isEmpty &&
      materiais.isEmpty &&
      ocorrencias.isEmpty &&
      prazos.isEmpty;

  @override
  List<Object?> get props => [clima, efetivo, materiais, ocorrencias, prazos];
}