import '../entidades/diario_obra.dart';

/// Contrato de persistência dos Diários de Obra (RDO).
abstract interface class DiarioRepositorio {
  Future<List<DiarioObra>> listarPorObra(String obraId);
  Future<DiarioObra?> porId(String id);
  Future<void> salvar(DiarioObra diario);
  Future<void> registrarPdf({required String id, required String caminhoPdf});

  /// Corrige a transcrição editada pelo engenheiro, sem mexer nos campos
  /// já extraídos da fala (efetivo, materiais, clima...).
  Future<void> atualizarTranscricao({required String id, required String texto});

  /// Apaga o RDO do banco e o arquivo de PDF gerado a partir dele.
  Future<void> excluir(DiarioObra diario);
}