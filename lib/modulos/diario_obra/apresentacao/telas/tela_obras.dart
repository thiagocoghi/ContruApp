import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/dominio/entidades/obra.dart';
import '../../../../motor_ia/apresentacao/widgets/banner_instalacao_ia.dart';
import '../bloc/obras_cubit.dart';

/// Tela inicial: lista de obras (Etapa 1).
class TelaObras extends StatelessWidget {
  const TelaObras({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EnginApp — Obras')),
      body: Column(
        children: [
          // Instalação automática da LLM na 1ª execução (só aparece enquanto
          // baixa/carrega; some quando a IA está pronta).
          const BannerInstalacaoIa(),
          Expanded(
            child: BlocBuilder<ObrasCubit, EstadoObras>(
              builder: (context, estado) {
                switch (estado.status) {
                  case StatusObras.carregando:
                    return const Center(child: CircularProgressIndicator());
                  case StatusObras.erro:
                    return _MensagemErro(
                      mensagem: estado.erro ?? 'Erro desconhecido.',
                      aoTentar: () => context.read<ObrasCubit>().carregar(),
                    );
                  case StatusObras.vazio:
                    return const _CentroMensagem(
                      titulo: 'Nenhuma obra cadastrada',
                      texto: 'Toque em + para cadastrar a primeira obra '
                          'e começar a registrar os diários por voz.',
                    );
                  case StatusObras.pronto:
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: estado.obras.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _CardObra(obra: estado.obras[i]),
                    );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/obra/nova');
        },
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nova obra'),
      ),
    );
  }
}

class _CardObra extends StatelessWidget {
  const _CardObra({required this.obra});

  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final inicio = DateFormat('dd/MM/yyyy').format(obra.dataInicio);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.engineering_outlined)),
        title: Text(obra.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (obra.cliente != null) 'Cliente: ${obra.cliente}',
          'Início: $inicio',
        ].join('\n')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.pushNamed(context, '/obra/diarios', arguments: obra),
      ),
    );
  }
}

class _CentroMensagem extends StatelessWidget {
  const _CentroMensagem({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, size: 64),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MensagemErro extends StatelessWidget {
  const _MensagemErro({required this.mensagem, required this.aoTentar});

  final String mensagem;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}