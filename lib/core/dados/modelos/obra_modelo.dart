import '../../dominio/entidades/obra.dart';

/// Mapeamento entre [Obra] e a linha da tabela `obras`.
class ObraModelo {
  ObraModelo._();

  static Map<String, dynamic> paraMapa(Obra obra) => {
        'id': obra.id,
        'nome': obra.nome,
        'cliente': obra.cliente,
        'localizacao': obra.localizacao,
        'data_inicio': obra.dataInicio.toIso8601String(),
        'data_fim': obra.dataFim?.toIso8601String(),
        'detalhes': obra.detalhes,
        'status': obra.status.name,
      };

  static Obra deMapa(Map<String, dynamic> mapa) => Obra(
        id: mapa['id'] as String,
        nome: mapa['nome'] as String,
        cliente: mapa['cliente'] as String?,
        localizacao: mapa['localizacao'] as String?,
        dataInicio: DateTime.parse(mapa['data_inicio'] as String),
        dataFim: mapa['data_fim'] == null
            ? null
            : DateTime.parse(mapa['data_fim'] as String),
        detalhes: mapa['detalhes'] as String?,
        status: _status(mapa['status'] as String?),
      );

  /// Linhas criadas antes da migração v2 não têm `status` (NULL).
  static ObraStatus _status(String? valor) => ObraStatus.values.firstWhere(
        (s) => s.name == valor,
        orElse: () => ObraStatus.ativa,
      );
}
