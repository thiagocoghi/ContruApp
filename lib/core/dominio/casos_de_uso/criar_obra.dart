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
    String? detalhes,
  }) async {
    final obra = Obra(
      id: gerarId(),
      nome: _nomeObrigatorio(nome),
      cliente: _vazioParaNull(cliente),
      localizacao: _vazioParaNull(localizacao),
      detalhes: _vazioParaNull(detalhes),
      dataInicio: dataInicio ?? DateTime.now(),
    );
    await _repositorio.salvar(obra);
    return obra;
  }

  String _nomeObrigatorio(String nome) {
    final limpo = nome.trim();
    if (limpo.isEmpty) {
      throw const FalhaDominio('Informe o nome da obra.');
    }
    return limpo;
  }

  String? _vazioParaNull(String? valor) {
    final limpo = valor?.trim();
    return (limpo == null || limpo.isEmpty) ? null : limpo;
  }
}

/// Edição dos dados de uma obra já cadastrada (nome, cliente, localização,
/// datas e observações do engenheiro).
class EditarObra {
  const EditarObra(this._repositorio);

  final ObraRepositorio _repositorio;

  Future<Obra> executar({
    required Obra obra,
    required String nome,
    String? cliente,
    String? localizacao,
    String? detalhes,
    required DateTime dataInicio,
    DateTime? dataFim,
  }) async {
    final limpo = nome.trim();
    if (limpo.isEmpty) {
      throw const FalhaDominio('Informe o nome da obra.');
    }

    final atualizada = Obra(
      id: obra.id,
      nome: limpo,
      cliente: _vazioParaNull(cliente),
      localizacao: _vazioParaNull(localizacao),
      detalhes: _vazioParaNull(detalhes),
      dataInicio: dataInicio,
      dataFim: dataFim,
      status: obra.status,
    );
    await _repositorio.atualizar(atualizada);
    return atualizada;
  }

  String? _vazioParaNull(String? valor) {
    final limpo = valor?.trim();
    return (limpo == null || limpo.isEmpty) ? null : limpo;
  }
}

/// Encerra a obra: grava a data de fim e tira do rol de obras em andamento.
class FecharObra {
  const FecharObra(this._repositorio);

  final ObraRepositorio _repositorio;

  Future<Obra> executar({required Obra obra, DateTime? dataFim}) async {
    final encerrada = obra.copiarCom(
      status: ObraStatus.concluida,
      dataFim: dataFim ?? DateTime.now(),
    );
    await _repositorio.atualizar(encerrada);
    return encerrada;
  }
}

/// Reabre uma obra encerrada (volta a aceitar diários).
class ReabrirObra {
  const ReabrirObra(this._repositorio);

  final ObraRepositorio _repositorio;

  Future<Obra> executar({required Obra obra}) async {
    // Construída na mão: `copiarCom(dataFim: null)` não limpa o campo, e aqui
    // limpar é justamente o ponto — a obra volta a ficar sem data de fim.
    final reaberta = Obra(
      id: obra.id,
      nome: obra.nome,
      cliente: obra.cliente,
      localizacao: obra.localizacao,
      detalhes: obra.detalhes,
      dataInicio: obra.dataInicio,
      dataFim: null,
      status: ObraStatus.ativa,
    );
    await _repositorio.atualizar(reaberta);
    return reaberta;
  }
}

/// Move a obra para a área de arquivo (e volta de lá).
class AlternarArquivamento {
  const AlternarArquivamento(this._repositorio);

  final ObraRepositorio _repositorio;

  Future<Obra> executar({required Obra obra}) async {
    final arquivando = obra.status != ObraStatus.arquivada;
    final alvo = Obra(
      id: obra.id,
      nome: obra.nome,
      cliente: obra.cliente,
      localizacao: obra.localizacao,
      detalhes: obra.detalhes,
      dataInicio: obra.dataInicio,
      dataFim: obra.dataFim,
      status: arquivando ? ObraStatus.arquivada : ObraStatus.ativa,
    );
    await _repositorio.atualizar(alvo);
    return alvo;
  }
}

/// Exclusão definitiva da obra e de todo o histórico ligado a ela.
class ExcluirObra {
  const ExcluirObra(this._repositorio);

  final ObraRepositorio _repositorio;

  Future<void> executar({required String obraId}) =>
      _repositorio.excluir(obraId);
}