import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/preparacao_ia_cubit.dart';

/// Banner de instalação automática da LLM (Qwen 2.5 1.5B).
///
/// Fica no topo da tela inicial: mostra o progresso do download/carga na
/// primeira execução, some quando a IA está pronta e vira um aviso com
/// "Tentar de novo" se a instalação falhar. Enquanto ele existe, o app já
/// funciona — a extração de RDO é feita pelas regras até o modelo estar
/// disponível.
class BannerInstalacaoIa extends StatelessWidget {
  const BannerInstalacaoIa({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PreparacaoIaCubit, EstadoIa>(
      builder: (context, estado) {
        switch (estado.status) {
          case StatusIa.pronto:
          case StatusIa.aguardando:
            return const SizedBox.shrink();
          case StatusIa.erro:
            return _AvisoErro(estado: estado);
          case StatusIa.baixando:
          case StatusIa.carregando:
            return _Progresso(estado: estado);
        }
      },
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso({required this.estado});

  final EstadoIa estado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carregando = estado.status == StatusIa.carregando;
    final fracao = carregando ? null : estado.fracao;

    final subtitulo = carregando
        ? 'Carregando o modelo na memória…'
        : fracao == null
            ? 'Preparando o modelo de IA…'
            : 'Baixando o modelo Qwen 2.5 1.5B — '
                '${(fracao * 100).round()}% de ~1 GB';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Instalando a IA do canteiro',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: fracao, minHeight: 6),
              ),
              const SizedBox(height: 8),
              Text(subtitulo, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                'Só na primeira execução. Depois a IA funciona 100% offline.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoErro extends StatelessWidget {
  const _AvisoErro({required this.estado});

  final EstadoIa estado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 18, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'IA não instalada',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                estado.mensagem ??
                    'Sem a IA a extração segue pelas regras padrão.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.read<PreparacaoIaCubit>().tentarNovamente(),
                  child: const Text('Tentar de novo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
