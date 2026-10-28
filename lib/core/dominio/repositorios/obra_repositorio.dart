import '../entidades/obra.dart';

/// Contrato de persistência de obras (implementado em `core/dados`).
abstract interface class ObraRepositorio {
  /// Lista todas as obras, sem filtrar por status.
  Future<List<Obra>> listar();

  /// Lista apenas as obras em andamento (esconde concluídas e arquivadas).
  Future<List<Obra>> listarAtivas();

  /// Lista obras encerradas e arquivadas — a área de arquivo do app.
  Future<List<Obra>> listarArquivadas();

  Future<Obra?> porId(String id);
  Future<void> salvar(Obra obra);

  /// Atualiza uma obra existente (edição de dados, observações, status).
  Future<void> atualizar(Obra obra);

  /// Apaga a obra e, em cascata, todos os diários e PDFs ligados a ela.
  Future<void> excluir(String id);
}