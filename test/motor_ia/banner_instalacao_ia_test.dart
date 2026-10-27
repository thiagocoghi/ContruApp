import 'package:engin_app/motor_ia/apresentacao/bloc/preparacao_ia_cubit.dart';
import 'package:engin_app/motor_ia/apresentacao/widgets/banner_instalacao_ia.dart';
import 'package:engin_app/motor_ia/dominio/interfaces/inferencia_slm.dart';
import 'package:engin_app/motor_ia/orquestrador_ia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// SLM falso: reporta 42% e conclui; pode falhar nas primeiras N tentativas.
class _Slm implements InferenciaSlm {
  _Slm({this.falharVezes = 0});

  int falharVezes;

  bool _pronto = false;

  @override
  bool get pronto => _pronto;

  @override
  Future<void> preparar({void Function(double? fracao)? aoProgresso}) async {
    aoProgresso?.call(0.42);
    if (falharVezes > 0) {
      falharVezes--;
      throw Exception('falha de rede');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
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

Future<void> _pumpar(WidgetTester tester, _Slm slm) async {
  await tester.pumpWidget(
    BlocProvider<PreparacaoIaCubit>(
      create: (_) => PreparacaoIaCubit(
        orquestrador: OrquestradorIa(slm: slm),
      )..iniciar(),
      child: const MaterialApp(
        home: Scaffold(body: BannerInstalacaoIa()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('mostra o progresso do download e some quando a IA fica pronta',
      (tester) async {
    await _pumpar(tester, _Slm());

    // Download em andamento: porcentagem visível e barra preenchida.
    expect(find.text('Instalando a IA do canteiro'), findsOneWidget);
    expect(find.textContaining('Baixando o modelo Qwen 2.5 1.5B'), findsOneWidget);
    expect(find.textContaining('42%'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value,
      0.42,
    );

    // Conclui o download/carga: o banner desaparece.
    await tester.pumpAndSettle();
    expect(find.text('Instalando a IA do canteiro'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('falha na instalação vira aviso com "Tentar de novo"',
      (tester) async {
    final slm = _Slm(falharVezes: 1);
    await _pumpar(tester, slm);
    await tester.pumpAndSettle();

    expect(find.text('IA não instalada'), findsOneWidget);
    expect(find.textContaining('regras'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Segunda tentativa dá certo e o banner some.
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(slm.pronto, isTrue);
    expect(find.text('IA não instalada'), findsNothing);
  });
}
