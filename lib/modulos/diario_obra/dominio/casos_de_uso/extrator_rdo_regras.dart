import '../entidades/diario_obra.dart';
import '../entidades/extracao_rdo.dart';
import '../interfaces/extrator_entidades.dart';

/// Extração determinística de entidades do RDO a partir do texto transcrito.
///
/// Segue o princípio do PRD (Etapa 2, item 2): a IA não faz cálculo nem
/// inferência aberta — regras determinísticas transformam o texto bruto em
/// dados estruturados, sem margem para alucinação. Quando o SLM on-device
/// for integrado (Gemma/Qwen), ele poderá complementar esta implementação
/// atrás da mesma interface [ExtratorEntidades].
class ExtratorRdoRegras implements ExtratorEntidades {
  const ExtratorRdoRegras();

  // ── Clima ────────────────────────────────────────────────────────────
  static final List<(RegExp, String)> _climas = [
    (RegExp(r'chuva|chuvos|chuvand|garoa|temporal|trovoad', caseSensitive: false), 'Chuva'),
    (RegExp(r'\bvento\b|ventand|rajada', caseSensitive: false), 'Vento'),
    (RegExp(r'nublad|encobert|nuvem|encobert', caseSensitive: false), 'Nublado'),
    (RegExp(r'ensolad|ensolarad|céu limpo|ceu limpo|tempo bom|\bsol\b', caseSensitive: false), 'Ensolarado'),
    (RegExp(r'\bcalor\b|quente|calorão', caseSensitive: false), 'Calor'),
    (RegExp(r'\bfrio\b|friagem|gelad', caseSensitive: false), 'Frio'),
    (RegExp(r'neblin|nevoeir|névoa|nevoa', caseSensitive: false), 'Névoa'),
    (RegExp(r'\bseco\b|sem chuva', caseSensitive: false), 'Seco'),
  ];

  // ── Efetivo ──────────────────────────────────────────────────────────
  static final RegExp _efetivoPorFuncao = RegExp(
    r'(\d+)\s*(?:de\s+)?'
    r'(operári[oa]s?|pedreir[oa]s?|ajudantes?|serventes?|mestres(?:\s+de\s+obra)?|'
    r'engenheir[oa]s?|eletricistas?|armadores?|marceneiros?|pintores?|soldadores?|'
    r'mecânicos?|motoristas?|pedreiros?|trabalhadores?|pessoas|homens|mão de obra)',
    caseSensitive: false,
  );
  static final RegExp _efetivoTotal = RegExp(
    r'efetivo\s+(?:de|total\s+de)\s+(\d+)',
    caseSensitive: false,
  );

  // ── Materiais ────────────────────────────────────────────────────────
  static final RegExp _material = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(sacos?|blocos?|tijolos?|pe[cç]as?|p[cç]s?|unidades?|folhas?|rolos?|'
    r'metros?(?:\s+(?:c(?:u|ú)bicos?|lineares?|quadrados?))?|m[²2³3]|'
    r'kg|quilos?|toneladas?|ton|litros?|baldes?|fardos?|jumbos?|carretis?)'
    r'(?:\s+(?:de\s+)?([a-zà-úç\s]{3,50}?))?'
    r'(?=[,;.\n!?]| e \d|\s|$)',
    caseSensitive: false,
  );

  static const List<String> _vocabularioMaterial = [
    'cimento', 'areia', 'brita', 'aço', 'aco', 'arame', 'argamassa', 'bloco',
    'tijolo', 'tinta', 'água', 'agua', 'cabo', 'fio', 'telha', 'tela',
    'concreto', 'ferro', 'vergalhão', 'vergalhao', 'compensado', 'madeira',
    'gesso', 'drywall', 'pvc', 'cano', 'rejunte', 'azulejo', 'piso',
    'cerâmica', 'ceramica', 'cal', 'alvenaria', 'eletroduto', 'disjuntor',
    'tomada', 'lâmpada', 'lampada', 'emulsão', 'emulsao', 'primer', 'forro',
    'drywall', 'serralheria', 'vidro', 'contrapiso', 'forro', 'material',
    'estrutura', 'vigas', 'viga', 'laje', 'fundações', 'fundacao', 'fundações',
  ];

  static const List<String> _marcadoresOcorrencia = [
    'atras', 'avaria', 'acidente', 'falha', 'problema', 'reclamaç',
    'falta', 'faltou', 'faltaram', 'interromp', 'parou', 'parada',
    'dano', 'quebra', 'defeito', 'sinistro', 'reprovaç', 'não conformidade',
    'nao conformidade', 'erro', 'extravio', 'roubo', 'obstru', 'travou',
    'danific', 'queimad', 'explos', 'quase acidente', 'risco',
  ];

  static const List<String> _marcadoresPrazo = [
    'prazo', 'entrega', 'entregar', 'finalizar', 'concluir', 'conclusão',
    'conclusao', 'previsto', 'previsão', 'previsao', 'urgente', 'amanhã',
    'amanha', 'atrasar', 'cronograma', 'para até', 'finalizar até',
  ];

  static const List<String> _negacoes = [
    'sem problema', 'sem atraso', 'sem falha', 'sem risco', 'sem dano',
    'não houve', 'nao houve', 'sem chuva', 'sem interrup', 'sem quebra',
  ];

  @override
  ExtracaoRdo extrair(String texto) {
    final bruto = texto.trim();
    if (bruto.isEmpty) return const ExtracaoRdo();

    final frases = _frasear(bruto);

    return ExtracaoRdo(
      clima: _extrairClima(bruto),
      efetivo: _extrairEfetivo(bruto),
      materiais: _extrairMateriais(bruto),
      ocorrencias: frases.where(_ehOcorrencia).toList(),
      prazos: frases.where(_ehPrazo).toList(),
    );
  }

  List<String> _frasear(String texto) => texto
      .split(RegExp(r'[.!?\n;]+'))
      .map((f) => f.trim())
      .where((f) => f.length > 3)
      .toList();

  String? _extrairClima(String texto) {
    for (final (padrao, rotulo) in _climas) {
      final match = padrao.firstMatch(texto);
      if (match == null) continue;
      if (_temNegacaoAntes(texto, match.start)) continue;
      return rotulo;
    }
    return null;
  }

  bool _temNegacaoAntes(String texto, int inicio) {
    final antes = texto
        .substring(0, inicio)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trimRight();
    // Ex.: "dia sem chuva" — a ocorrência de 'chuva' vem logo após 'sem'.
    return antes.endsWith('sem') ||
        antes.endsWith('sem e') ||
        antes.endsWith('sem ou');
  }

  List<EfetivoItem> _extrairEfetivo(String texto) {
    final acumulado = <String, int>{};

    for (final match in _efetivoPorFuncao.allMatches(texto)) {
      final quantidade = int.tryParse(match.group(1)!);
      if (quantidade == null || quantidade <= 0) continue;
      final funcao = _capitalizar(match.group(2)!);
      acumulado.update(funcao, (v) => v + quantidade, ifAbsent: () => quantidade);
    }

    for (final match in _efetivoTotal.allMatches(texto)) {
      final quantidade = int.tryParse(match.group(1)!);
      if (quantidade != null && quantidade > 0) {
        acumulado.putIfAbsent('Efetivo total', () => quantidade);
      }
    }

    return acumulado.entries
        .map((e) => EfetivoItem(funcao: e.key, quantidade: e.value))
        .toList();
  }

  List<MaterialItem> _extrairMateriais(String texto) {
    final itens = <MaterialItem>[];
    for (final match in _material.allMatches(texto)) {
      final quantidade = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (quantidade == null || quantidade <= 0) continue;

      final unidadeOriginal = match.group(2)!;
      final capturado = match.group(3)?.trim().toLowerCase();
      final semNome = capturado == null || capturado.isEmpty;

      // "20 sacos de cimento" → nome='cimento', unidade='saco'.
      // "500 tijolos"          → nome='tijolo',  unidade='unidade'.
      final unidade =
          semNome ? 'unidade' : _normalizarUnidade(unidadeOriginal);
      final nome =
          semNome ? _normalizarUnidade(unidadeOriginal) : capturado;
      if (!_vocabularioMaterial.any(nome.contains)) continue;

      itens.add(MaterialItem(
        material: _capitalizar(nome),
        quantidade: quantidade,
        unidade: unidade,
      ));
    }
    return itens;
  }

  bool _ehOcorrencia(String frase) {
    final minusc = frase.toLowerCase();
    if (_negacoes.any(minusc.contains)) return false;
    return _marcadoresOcorrencia.any(minusc.contains);
  }

  bool _ehPrazo(String frase) {
    final minusc = frase.toLowerCase();
    return _marcadoresPrazo.any(minusc.contains);
  }

  String _normalizarUnidade(String unidade) {
    final u = unidade.toLowerCase().trim();
    if (u.startsWith('m²') || u == 'm2' || u.contains('quadrad')) return 'm²';
    if (u.startsWith('m³') || u == 'm3' || u.contains('cúbic') || u.contains('cubic')) {
      return 'm³';
    }
    if (u.contains('linear')) return 'm';
    if (u.startsWith('metro')) return 'm';
    const plurais = {
      'sacos': 'saco',
      'blocos': 'bloco',
      'tijolos': 'tijolo',
      'peças': 'peça',
      'pçs': 'peça',
      'unidades': 'unidade',
      'folhas': 'folha',
      'rolos': 'rolo',
      'quilos': 'kg',
      'toneladas': 'tonelada',
      'baldes': 'balde',
      'fardos': 'fardo',
      'jumbos': 'jumbo',
      'carretis': 'carretel',
    };
    return plurais[u] ?? u;
  }

  String _capitalizar(String texto) {
    final limpo = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpo.isEmpty) return limpo;
    return limpo[0].toUpperCase() + limpo.substring(1);
  }
}