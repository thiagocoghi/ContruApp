import '../../infra/util/gerador_ids.dart';
import '../entidades/obra.dart';
import '../erros/falha_dominio.dart';
import '../repositorios/obra_repositorio.dart';

/// Casos de uso de obras (cadastro básico — âncora de todos os módulos).
class CriarObra {
  const CriarObra(this._repositorio);

  final ObraRepositorio _repositorio;

  Future<Obra> executar({
    required String nome,
    DateTime? dataInicio,
    String? cliente,
    String? localizacao,
  }) async {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw const FalhaDominio('Informe o nome da obra.');
    }

    final obra = Obra(
      id: gerarId(),
      nome: nomeLimpo,
      cliente: _vazioParaNull(cliente),
      localizacao: _vazioParaNull(localizacao),
      dataInicio: dataInicio ?? DateTime.now(),
    );
    await _repositorio.salvar(obra);
    return obra;
  }

  String? _vazioParaNull(String? valor) {
    final limpo = valor?.trim();
    return (limpo == null || limpo.isEmpty) ? null : limpo;
  }
}