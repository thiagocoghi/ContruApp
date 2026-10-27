/// Erro de domínio com mensagem amigável para exibição na UI.
class FalhaDominio implements Exception {
  const FalhaDominio(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}