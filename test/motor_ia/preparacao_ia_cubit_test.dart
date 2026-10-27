import 'package:engin_app/motor_ia/apresentacao/bloc/preparacao_ia_cubit.dart';
import 'package:engin_app/motor_ia/dominio/interfaces/inferencia_slm.dart';
import 'package:engin_app/motor_ia/orquestrador_ia.dart';
import 'package:flutter_test/flutter_test.dart';

/// SLM falso controlável: reporta progresso, pode falhar e "fica pronto".
class _SlmFalso implements InferenciaSlm {
  _SlmFalso({this.falharNaVez = 0});

  /// Quantas primeiras chamadas de [preparar] devem falhar.
  int falharNaVez;

  bool _pronto = false;
  int preparacoes = 0;
  final List<double?> progressos = [];

  @override
  bool get pronto => _pronto;

  @override
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) async {
    preparacoes++;
    aoProgresso?.call(0.25);
    aoProgresso?.call(0.6);

    if (falharNaVez > 0) {
      falharNaVez--;
      aoProgresso?.call(0.6);
      throw Exception('sem rede');
    }

    aoProgresso?.call(1.0);
    _pronto = true;
  }

  @override
  Future<String> completar({
    required String instrucao,
    required String entrada,
    int maxTokens = 384,
  }) async =>
      '';

  @override
  Future<void> liberar() async {
    _pronto = false;
  }
}

void main() {
  group('PreparacaoIaCubit — instalação automática da LLM', () {
    test('instala, reporta progresso e termina pronto', () async {
      final slm = _SlmFalso();
      final cubit = PreparacaoIaCubit(
        orquestrador: OrquestradorIa(slm: slm),
      );

      final estados = <EstadoIa>[];
      final assinatura = cubit.stream.listen(estados.add);

      await cubit.iniciar();
      // O stream do Cubit entrega os estados em microtasks.
      await Future<void>.delayed(Duration.zero);

      expect(slm.preparacoes, 1);
      expect(cubit.instalada, isTrue);
      expect(cubit.state.status, StatusIa.pronto);

      // Progresso em porcentagem arredondada (0.25 → 0.25, 0.6 → 0.6).
      expect(
        estados.map((e) => e.status),
        containsAllInOrder([StatusIa.baixando, StatusIa.carregando, StatusIa.pronto]),
      );
      expect(
        estados.where((e) => e.status == StatusIa.baixando).map((e) => e.fracao),
        containsAll([0.25, 0.6]),
      );

      await assinatura.cancel();
      await cubit.close();
    });

    test('falha vira estado de erro com mensagem amigável', () async {
      final slm = _SlmFalso(falharNaVez: 1);
      final cubit = PreparacaoIaCubit(
        orquestrador: OrquestradorIa(slm: slm),
      );

      await cubit.iniciar();

      expect(cubit.state.status, StatusIa.erro);
      expect(cubit.state.mensagem, isNotEmpty);
      expect(cubit.instalada, isFalse);

      // "Tentar de novo" retoma a instalação e dá certo.
      await cubit.tentarNovamente();
      expect(cubit.state.status, StatusIa.pronto);
      expect(slm.preparacoes, 2);

      await cubit.close();
    });

    test('quando a IA já está pronta não baixa de novo', () async {
      final slm = _SlmFalso();
      final orquestrador = OrquestradorIa(slm: slm);
      await orquestrador.preparar();

      final cubit = PreparacaoIaCubit(orquestrador: orquestrador);
      await cubit.iniciar();

      expect(slm.preparacoes, 1);
      expect(cubit.state.status, StatusIa.pronto);

      await cubit.close();
    });

    test('chamadas concorrentes iniciam um único download', () async {
      final slm = _SlmFalso();
      final cubit = PreparacaoIaCubit(
        orquestrador: OrquestradorIa(slm: slm),
      );

      await Future.wait([cubit.iniciar(), cubit.iniciar(), cubit.iniciar()]);

      expect(slm.preparacoes, 1);
      expect(cubit.state.status, StatusIa.pronto);

      await cubit.close();
    });

    test('emite pronto quando o modelo já veio pronto do orquestrador',
        () async {
      final slm = _SlmFalso();
      final orquestrador = OrquestradorIa(slm: slm);
      await orquestrador.preparar();

      final cubit = PreparacaoIaCubit(orquestrador: orquestrador);
      await cubit.iniciar();

      expect(cubit.state, const EstadoIa.pronto());

      await cubit.close();
    });
  });
}
