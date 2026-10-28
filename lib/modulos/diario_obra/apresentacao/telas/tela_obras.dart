import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/dominio/entidades/obra.dart';
import '../../../../motor_ia/apresentacao/widgets/banner_instalacao_ia.dart';
import '../bloc/obras_cubit.dart';

/// Tela inicial: lista de obras (Etapa 1).
///
/// Separa o que está em andamento do que foi encerrado/arquivado, e dá ações
/// por obra (editar, encerrar, arquivar, excluir) pelo menu de contexto.
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
                    return _ListaObras(estado: estado);
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

class _ListaObras extends StatelessWidget {
  const _ListaObras({required this.estado});

  final EstadoObras estado;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final obra in estado.obras) _CardObra(obra: obra),
        if (estado.arquivadas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'ENCERRADAS E ARQUIVADAS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          for (final obra in estado.arquivadas) _CardObra(obra: obra),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _CardObra extends StatelessWidget {
  const _CardObra({required this.obra});

  final Obra obra;

  Future<void> _acao(
    BuildContext context,
    Future<void> Function(ObrasCubit) acao,
  ) async {
    final cubit = context.read<ObrasCubit>();
    await acao(cubit);
    if (!context.mounted) return;
    final erro = cubit.state.erro;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  /// Exclusão definitiva: exige digitar o nome da obra, porque apaga também
  /// todos os diários e PDFs — não há como desfazer.
  Future<void> _confirmarExclusao(BuildContext context) async {
    final controlador = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir esta obra?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${obra.nome}" e todo o histórico ligado a ela serão apagados '
              'definitivamente: diários (RDO) e relatórios em PDF.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controlador,
              decoration: const InputDecoration(
                labelText: 'Digite o nome da obra para confirmar',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controlador.text.trim() == obra.nome,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado == true && context.mounted) {
      await _acao(context, (cubit) => cubit.excluir(obra: obra));
    }
  }

  Future<void> _menu(BuildContext context) async {
    final opcao = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar dados e observações'),
              onTap: () => Navigator.pop(context, 'editar'),
            ),
            if (obra.estaAtiva)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Encerrar obra'),
                subtitle: const Text('Grava a data de fim e sai da lista '
                    'principal'),
                onTap: () => Navigator.pop(context, 'encerrar'),
              )
            else
              ListTile(
                leading: const Icon(Icons.replay_outlined),
                title: const Text('Reabrir obra'),
                onTap: () => Navigator.pop(context, 'reabrir'),
              ),
            ListTile(
              leading: Icon(
                obra.status == ObraStatus.arquivada
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(
                obra.status == ObraStatus.arquivada
                    ? 'Desarquivar'
                    : 'Arquivar',
              ),
              onTap: () => Navigator.pop(context, 'arquivar'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Excluir obra e histórico',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'excluir'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || opcao == null) return;
    switch (opcao) {
      case 'editar':
        await Navigator.pushNamed(context, '/obra/editar', arguments: obra);
      case 'encerrar':
        await _confirmarEncerramento(context);
      case 'reabrir':
        await _acao(context, (cubit) => cubit.reabrir(obra: obra));
      case 'arquivar':
        await _acao(context, (cubit) => cubit.alternarArquivo(obra: obra));
      case 'excluir':
        await _confirmarExclusao(context);
    }
  }

  Future<void> _confirmarEncerramento(BuildContext context) async {
    var data = DateTime.now();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Encerrar a obra?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A obra sai da lista principal e passa a ter data de fim. '
                'O histórico continua legível e pode ser reaberto depois.',
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data de fim'),
                subtitle: Text(
                  '${data.day.toString().padLeft(2, '0')}/'
                  '${data.month.toString().padLeft(2, '0')}/${data.year}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final escolhida = await showDatePicker(
                    context: context,
                    initialDate: data,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (escolhida != null) setState(() => data = escolhida);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Encerrar'),
            ),
          ],
        ),
      ),
    );

    if (confirmado == true && context.mounted) {
      await _acao(context, (cubit) => cubit.fechar(obra: obra, dataFim: data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicio = DateFormat('dd/MM/yyyy').format(obra.dataInicio);
    final fim = obra.dataFim == null
        ? null
        : DateFormat('dd/MM/yyyy').format(obra.dataFim!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_icone),
        ),
        title: Text(obra.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (obra.cliente != null) 'Cliente: ${obra.cliente}',
          if (obra.localizacao != null) 'Local: ${obra.localizacao}',
          'Início: $inicio${fim == null ? '' : ' — Fim: $fim'}',
          if (obra.detalhes != null && obra.detalhes!.trim().isNotEmpty)
            'Obs.: ${obra.detalhes}',
        ].join('\n')),
        isThreeLine: obra.detalhes != null && obra.detalhes!.trim().isNotEmpty,
        trailing: IconButton(
          tooltip: 'Ações da obra',
          icon: const Icon(Icons.more_vert),
          onPressed: () => _menu(context),
        ),
        onTap: () =>
            Navigator.pushNamed(context, '/obra/diarios', arguments: obra),
      ),
    );
  }

  IconData get _icone => switch (obra.status) {
        ObraStatus.ativa => Icons.engineering_outlined,
        ObraStatus.concluida => Icons.verified_outlined,
        ObraStatus.arquivada => Icons.archive_outlined,
      };
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