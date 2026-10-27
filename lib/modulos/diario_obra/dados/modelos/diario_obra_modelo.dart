import 'dart:convert';

import '../../dominio/entidades/diario_obra.dart';

/// Mapeamento entre [DiarioObra] e a linha da tabela `diarios_obra`.
class DiarioObraModelo {
  DiarioObraModelo._();

  static Map<String, dynamic> paraMapa(DiarioObra d) => {
        'id': d.id,
        'obra_id': d.obraId,
        'data': d.data.toIso8601String(),
        'transcricao_raw': d.transcricaoRaw,
        'clima': d.clima,
        'efetivo_json': _codificar(d.efetivo.map(_efetivoParaMapa).toList()),
        'ocorrencias_json': _codificar(d.ocorrencias),
        'materiais_json': _codificar(d.materiais.map(_materialParaMapa).toList()),
        'prazos_json': _codificar(d.prazos),
        'pdf_path': d.pdfPath,
      };

  static DiarioObra deMapa(Map<String, dynamic> m) => DiarioObra(
        id: m['id'] as String,
        obraId: m['obra_id'] as String,
        data: DateTime.parse(m['data'] as String),
        transcricaoRaw: (m['transcricao_raw'] as String?) ?? '',
        clima: m['clima'] as String?,
        efetivo: _decodificarLista(m['efetivo_json'])
            .map(_efetivoDeMapa)
            .toList(),
        ocorrencias: _decodificarLista(m['ocorrencias_json'])
            .map((e) => e.toString())
            .toList(),
        materiais: _decodificarLista(m['materiais_json'])
            .map(_materialDeMapa)
            .toList(),
        prazos: _decodificarLista(m['prazos_json'])
            .map((e) => e.toString())
            .toList(),
        pdfPath: m['pdf_path'] as String?,
      );

  static String _codificar(Object? valor) => jsonEncode(valor);

  static List<dynamic> _decodificarLista(Object? bruto) {
    if (bruto == null || (bruto as String).isEmpty) return const [];
    final decodificado = jsonDecode(bruto);
    return decodificado is List ? decodificado : const [];
  }

  static Map<String, dynamic> _efetivoParaMapa(EfetivoItem e) => {
        'funcao': e.funcao,
        'quantidade': e.quantidade,
      };

  static EfetivoItem _efetivoDeMapa(dynamic m) => EfetivoItem(
        funcao: m['funcao'] as String,
        quantidade: (m['quantidade'] as num).toInt(),
      );

  static Map<String, dynamic> _materialParaMapa(MaterialItem m) => {
        'material': m.material,
        'quantidade': m.quantidade,
        'unidade': m.unidade,
      };

  static MaterialItem _materialDeMapa(dynamic m) => MaterialItem(
        material: m['material'] as String,
        quantidade: (m['quantidade'] as num).toDouble(),
        unidade: m['unidade'] as String,
      );
}