import 'dart:math';

final Random _random = Random();

/// Gera um ID local único (sem servidor — app é offline-first).
String gerarId() {
  final tempo = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final sorteio = _random.nextInt(0x7fffffff).toRadixString(36);
  return '${tempo}_$sorteio';
}