import '../entidades/diario_obra.dart';

/// Contrato de persistência dos Diários de Obra (RDO).
abstract interface class DiarioRepositorio {
  Future<List<DiarioObra>> listarPorObra(String obraId);
  Future<DiarioObra?> porId(String id);
  Future<void> salvar(DiarioObra diario);
  Future<void> registrarPdf({required String id, required String caminhoPdf});
}