import '../../dominio/entidades/obra.dart';
import '../../dominio/repositorios/obra_repositorio.dart';
import '../banco_dados/daos/obras_dao.dart';
import '../modelos/obra_modelo.dart';

/// Implementação SQLite do repositório de obras.
class ObraRepositorioSqlite implements ObraRepositorio {
  ObraRepositorioSqlite(this._dao);

  final ObrasDao _dao;

  @override
  Future<List<Obra>> listar() async {
    final linhas = await _dao.listar();
    return linhas.map(ObraModelo.deMapa).toList();
  }

  @override
  Future<List<Obra>> listarAtivas() =>
      _porStatuses([ObraStatus.ativa.name]);

  @override
  Future<List<Obra>> listarArquivadas() =>
      _porStatuses([ObraStatus.concluida.name, ObraStatus.arquivada.name]);

  Future<List<Obra>> _porStatuses(List<String> statuses) async {
    final linhas = await _dao.listarPorStatus(statuses);
    return linhas.map(ObraModelo.deMapa).toList();
  }

  @override
  Future<Obra?> porId(String id) async {
    final linha = await _dao.porId(id);
    return linha == null ? null : ObraModelo.deMapa(linha);
  }

  @override
  Future<void> salvar(Obra obra) => _dao.inserir(ObraModelo.paraMapa(obra));

  @override
  Future<void> atualizar(Obra obra) => _dao.atualizar(ObraModelo.paraMapa(obra));

  @override
  Future<void> excluir(String id) => _dao.excluirComDiarios(id);
}