import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/registrador_dependencias.dart';
import '../../../../core/dominio/entidades/obra.dart';
import '../bloc/gravacao_cubit.dart';

/// Fluxo de gravação do Diário de Obra por voz (Etapa 1 do PRD).
class TelaGravacao extends StatelessWidget {
  const TelaGravacao({super.key, required this.obra});

  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final di = RegistrarDependencias.instancia;

    return BlocProvider(
      create: (_) => GravacaoCubit(
        gravador: di.gravador,
        montarDiario: di.montarDiarioPorVoz,
        repositorio: di.diarios,
        obraId: obra.id,
      ),
      child: Scaffold(
        appBar: AppBar(title: Text('Diário — ${obra.nome}')),
        body: BlocBuilder<GravacaoCubit, EstadoGravacao>(
          builder: (context, estado) => switch (estado.status) {
            StatusGravacao.inicial => _TelaInicial(cubit: context.read<GravacaoCubit>()),
            StatusGravacao.gravando => _TelaGravando(
                duracao: estado.duracao,
                cubit: context.read<GravacaoCubit>(),
              ),
            StatusGravacao.processando => const _TelaProcessando(),
            StatusGravacao.pronto => _TelaPreview(
                cubit: context.read<GravacaoCubit>(),
                estado: estado,
              ),
            StatusGravacao.erro => _TelaErro(
                mensagem: estado.erro ?? 'Erro desconhecido.',
                cubit: context.read<GravacaoCubit>(),
              ),
          },
        ),
      ),
    );
  }
}

class _TelaInicial extends StatelessWidget {
  const _TelaInicial({required this.cubit});

  final GravacaoCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq, size: 72),
            const SizedBox(height: 16),
            Text(
              'Relato do dia',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque no microfone e fale seu relatório diário:\n'
              'mão de obra, materiais, clima, ocorrências e prazos.\n\n'
              'A transcrição é 100% local — nada sai do aparelho.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FloatingActionButton.large(
              heroTag: 'gravar',
              onPressed: cubit.iniciar,
              child: const Icon(Icons.mic, size: 40),
            ),
            const SizedBox(height: 8),
            const Text('Toque para gravar'),
          ],
        ),
      ),
    );
  }
}

class _TelaGravando extends StatelessWidget {
  const _TelaGravando({required this.duracao, required this.cubit});

  final Duration duracao;
  final GravacaoCubit cubit;

  String get _textoCronometro {
    final m = duracao.inMinutes.toString().padLeft(2, '0');
    final s = (duracao.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PontoGravando(),
          const SizedBox(height: 16),
          Text(
            _textoCronometro,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          const Text('Gravando... fale com naturalidade'),
          const SizedBox(height: 32),
          FloatingActionButton.large(
            heroTag: 'parar',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: cubit.parar,
            child: const Icon(Icons.stop, size: 40),
          ),
          const SizedBox(height: 8),
          const Text('Toque para encerrar'),
        ],
      ),
    );
  }
}

class _PontoGravando extends StatefulWidget {
  const _PontoGravando();

  @override
  State<_PontoGravando> createState() => _PontoGravandoState();
}

class _PontoGravandoState extends State<_PontoGravando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0.4,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TelaProcessando extends StatelessWidget {
  const _TelaProcessando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Transcrevendo no dispositivo...\n'
              'Na primeira vez o modelo de voz é baixado (≈75 MB).',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TelaPreview extends StatelessWidget {
  const _TelaPreview({required this.cubit, required this.estado});

  final GravacaoCubit cubit;
  final EstadoGravacao estado;

  @override
  Widget build(BuildContext context) {
    final diario = estado.diario!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('RDO extraído', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (diario.clima != null)
                    Chip(
                      avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                      label: Text(diario.clima!),
                    ),
                  for (final e in diario.efetivo)
                    Chip(
                      avatar: const Icon(Icons.groups_outlined, size: 18),
                      label: Text('${e.quantidade} ${e.funcao}'),
                    ),
                  for (final m in diario.materiais)
                    Chip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text(
                        '${m.quantidade % 1 == 0 ? m.quantidade.toInt() : m.quantidade} '
                        '${m.unidade} de ${m.material}',
                      ),
                    ),
                ],
              ),
              if (diario.ocorrencias.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Ocorrências',
                    style: Theme.of(context).textTheme.titleMedium),
                for (final o in diario.ocorrencias)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $o'),
                  ),
              ],
              if (diario.prazos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Prazos',
                    style: Theme.of(context).textTheme.titleMedium),
                for (final p in diario.prazos)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $p'),
                  ),
              ],
              const SizedBox(height: 16),
              Text('Transcrição completa',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                diario.transcricaoRaw,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: cubit.descartar,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final salvo = await cubit.salvar();
                      if (salvo && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('Salvar diário'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TelaErro extends StatelessWidget {
  const _TelaErro({required this.mensagem, required this.cubit});

  final String mensagem;
  final GravacaoCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: cubit.iniciar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}