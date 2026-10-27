import '../entidades/obra.dart';

/// Contrato de persistência de obras (implementado em `core/dados`).
abstract interface class ObraRepositorio {
  Future<List<Obra>> listar();
  Future<Obra?> porId(String id);
  Future<void> salvar(Obra obra);
}