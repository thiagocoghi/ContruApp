import 'package:equatable/equatable.dart';

/// Registro de efetivo extraído da fala (ex.: 12 operários).
class EfetivoItem extends Equatable {
  const EfetivoItem({required this.funcao, required this.quantidade});

  final String funcao;
  final int quantidade;

  @override
  List<Object?> get props => [funcao, quantidade];
}

/// Material utilizado extraído da fala (ex.: 20 sacos de cimento).
class MaterialItem extends Equatable {
  const MaterialItem({
    required this.material,
    required this.quantidade,
    required this.unidade,
  });

  final String material;
  final double quantidade;
  final String unidade;

  @override
  List<Object?> get props => [material, quantidade, unidade];
}

/// Relatório Diário de Obra (RDO) — tabela `diarios_obra`.
class DiarioObra extends Equatable {
  const DiarioObra({
    required this.id,
    required this.obraId,
    required this.data,
    required this.transcricaoRaw,
    this.clima,
    this.efetivo = const [],
    this.materiais = const [],
    this.ocorrencias = const [],
    this.prazos = const [],
    this.pdfPath,
  });

  final String id;
  final String obraId;
  final DateTime data;
  final String transcricaoRaw;
  final String? clima;
  final List<EfetivoItem> efetivo;
  final List<MaterialItem> materiais;
  final List<String> ocorrencias;
  final List<String> prazos;
  final String? pdfPath;

  DiarioObra copiarCom({String? pdfPath}) => DiarioObra(
        id: id,
        obraId: obraId,
        data: data,
        transcricaoRaw: transcricaoRaw,
        clima: clima,
        efetivo: efetivo,
        materiais: materiais,
        ocorrencias: ocorrencias,
        prazos: prazos,
        pdfPath: pdfPath ?? this.pdfPath,
      );

  @override
  List<Object?> get props => [
        id,
        obraId,
        data,
        transcricaoRaw,
        clima,
        efetivo,
        materiais,
        ocorrencias,
        prazos,
        pdfPath,
      ];
}