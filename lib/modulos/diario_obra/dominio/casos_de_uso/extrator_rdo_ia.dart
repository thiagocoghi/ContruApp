import 'dart:convert';

import '../../../../motor_ia/dominio/interfaces/inferencia_slm.dart';
import '../entidades/diario_obra.dart';
import '../entidades/extracao_rdo.dart';
import '../interfaces/extrator_entidades.dart';

/// Extração de entidades do RDO via SLM on-device (Qwen 2.5 1.5B).
///
/// Envia a transcrição ao modelo com uma instrução que pede um JSON no schema
/// de [ExtracaoRdo] e converte a resposta. O PRD mantém a determinística como
/// piso de qualidade (Seção 2, item 2): quem decide o fallback é o
/// `OrquestradorIa`, por isso este extrator propaga a falha em vez de
/// escondê-la.
class ExtratorRdoIa implements ExtratorEntidadesAsync {
  const ExtratorRdoIa({required this.slm, this.maxTokens = 384});

  final InferenciaSlm slm;
  final int maxTokens;

  /// Instrução única (system) — schema do RDO em PT-BR.
  static const instrucao = '''
Você é um extrator de dados de Relatório Diário de Obra (RDO) em português do Brasil.
Receberá a transcrição de um áudio gravado no canteiro.
Responda SOMENTE com um objeto JSON válido, sem comentários e sem cercas de código:
{
  "clima": string ou null,
  "efetivo": [{"funcao": string, "quantidade": inteiro}],
  "materiais": [{"material": string, "quantidade": número, "unidade": string}],
  "ocorrencias": [string],
  "prazos": [string]
}
Regras:
- "clima": uma única condição (ex.: "Chuva", "Nublado", "Ensolarado") ou null.
- "efetivo": trabalhadores por função (ex.: "Pedreiro", "Eletricista").
- "materiais": apenas quantidades com unidade (saco, bloco, m, m², m³, kg, litro...).
- "ocorrencias": frases sobre atrasos, paradas, danos, falhas ou riscos.
- "prazos": frases com prazos, entregas ou datas previstas.
- Use null ou lista vazia quando não houver informação. Nunca invente dados.''';

  @override
  Future<ExtracaoRdo> extrair(String texto) async {
    final bruto = texto.trim();
    if (bruto.isEmpty) return const ExtracaoRdo();

    final resposta = await slm.completar(
      instrucao: instrucao,
      entrada: bruto,
      maxTokens: maxTokens,
    );

    return interpretarResposta(resposta);
  }

  /// Converte a resposta (possivelmente cercada de ``` e com ruído) em
  /// [ExtracaoRdo]. Lança [FormatException] quando não há JSON utilizável —
  /// o `OrquestradorIa` captura e cai para as regras.
  ///
  /// Público para permitir teste unitário do parser sem o runtime nativo.
  ExtracaoRdo interpretarResposta(String resposta) {
    final objeto = jsonDecode(_localizarJson(resposta));
    if (objeto is! Map<String, dynamic>) {
      throw const FormatException('Resposta do SLM não é um objeto JSON.');
    }

    return ExtracaoRdo(
      clima: _texto(objeto['clima']),
      efetivo: _efetivo(objeto['efetivo']),
      materiais: _materiais(objeto['materiais']),
      ocorrencias: _listaTextos(objeto['ocorrencias']),
      prazos: _listaTextos(objeto['prazos']),
    );
  }

  /// Modelos costumam envolver o JSON em cercas de código ou precedê-lo com
  /// texto — aqui vale o primeiro objeto JSON completo da resposta.
  static String _localizarJson(String resposta) {
    final inicio = resposta.indexOf('{');
    final fim = resposta.lastIndexOf('}');
    if (inicio < 0 || fim <= inicio) {
      throw const FormatException('Resposta do SLM não contém JSON.');
    }
    return resposta.substring(inicio, fim + 1);
  }

  static String? _texto(dynamic valor) {
    if (valor is! String) return null;
    final limpo = valor.trim();
    if (limpo.isEmpty || limpo.toLowerCase() == 'null') return null;
    return limpo;
  }

  static List<String> _listaTextos(dynamic valor) {
    if (valor is! List) return const [];
    return valor
        .map(_texto)
        .whereType<String>()
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static List<EfetivoItem> _efetivo(dynamic valor) {
    if (valor is! List) return const [];
    final itens = <EfetivoItem>[];
    for (final item in valor) {
      if (item is! Map) continue;
      final funcao = _texto(item['funcao']);
      final quantidade = _inteiro(item['quantidade']);
      if (funcao == null || quantidade == null || quantidade <= 0) continue;
      itens.add(EfetivoItem(funcao: funcao, quantidade: quantidade));
    }
    return itens;
  }

  static List<MaterialItem> _materiais(dynamic valor) {
    if (valor is! List) return const [];
    final itens = <MaterialItem>[];
    for (final item in valor) {
      if (item is! Map) continue;
      final material = _texto(item['material']);
      final quantidade = _numero(item['quantidade']);
      if (material == null || quantidade == null || quantidade <= 0) continue;
      itens.add(MaterialItem(
        material: material,
        quantidade: quantidade,
        unidade: _texto(item['unidade']) ?? 'unidade',
      ));
    }
    return itens;
  }

  static int? _inteiro(dynamic valor) {
    final numero = _numero(valor);
    return numero?.round();
  }

  static double? _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      return double.tryParse(valor.trim().replaceAll(',', '.'));
    }
    return null;
  }
}
