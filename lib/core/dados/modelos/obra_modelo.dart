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
      };

  static Obra deMapa(Map<String, dynamic> mapa) => Obra(
        id: mapa['id'] as String,
        nome: mapa['nome'] as String,
        cliente: mapa['cliente'] as String?,
        localizacao: mapa['localizacao'] as String?,
        dataInicio:
            DateTime.parse(mapa['data_inicio'] as String),
      );
}