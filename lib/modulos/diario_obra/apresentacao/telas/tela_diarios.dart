import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/registrador_dependencias.dart';
import '../../../../core/dominio/entidades/obra.dart';
import '../../dominio/entidades/diario_obra.dart';
import '../bloc/diarios_cubit.dart';

/// Lista dos Diários de Obra (RDO) de uma obra.
class TelaDiarios extends StatelessWidget {
  const TelaDiarios({super.key, required this.obra});

  final Obra obra;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiariosCubit(
        repositorio: RegistrarDependencias.instancia.diarios,
        obraId: obra.id,
      )..carregar(),
      // Builder desce o contexto para baixo do BlocProvider: sem ele, o
      // callback do FAB capturaria o contexto de TelaDiarios (acima do
      // provider) e o `context.read` lançaria exceção em runtime.
      child: Builder(
        builder: (context) => Scaffold(
        appBar: AppBar(title: Text(obra.nome)),
        body: BlocBuilder<DiariosCubit, EstadoDiarios>(
          builder: (context, estado) {
            switch (estado.status) {
              case StatusDiarios.carregando:
                return const Center(child: CircularProgressIndicator());
              case StatusDiarios.erro:
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(estado.erro ?? 'Erro desconhecido.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            context.read<DiariosCubit>().carregar(),
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  ),
                );
              case StatusDiarios.vazio:
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum diário registrado ainda.\n\n'
                      'Toque em + e grave seu relatório falando.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              case StatusDiarios.pronto:
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: estado.diarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                    _CardDiario(diario: estado.diarios[i], obra: obra),
                );
            }
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, '/diario/nova', arguments: obra);
            // Volta da gravação: novo RDO pode ter entrado.
            if (context.mounted) {
              context.read<DiariosCubit>().carregar();
            }
          },
          icon: const Icon(Icons.mic_outlined),
          label: const Text('Novo diário por voz'),
        ),
      ),
      ),
    );
  }
}

class _CardDiario extends StatelessWidget {
  const _CardDiario({required this.diario, required this.obra});

  final DiarioObra diario;
  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final data = DateFormat('dd/MM/yyyy').format(diario.data);
    final efetivoTotal =
        diario.efetivo.fold<int>(0, (s, e) => s + e.quantidade);

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
        title: Text('RDO — $data'),
        subtitle: Text([
          if (diario.clima != null) 'Clima: ${diario.clima}',
          if (efetivoTotal > 0) 'Efetivo: $efetivoTotal pessoas',
          if (diario.ocorrencias.isNotEmpty)
            'Ocorrências: ${diario.ocorrencias.length}',
          if (diario.pdfPath != null) 'PDF gerado ✓',
        ].join('\n')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          // `true` volta da tela de detalhe quando o RDO foi excluído ou a
          // transcrição corrigida — aí a lista precisa ser recarregada.
          final alterado = await Navigator.pushNamed(
            context,
            '/diario/detalhe',
            arguments: (obra: obra, diario: diario),
          );
          if (alterado == true && context.mounted) {
            context.read<DiariosCubit>().carregar();
          }
        },
      ),
    );
  }
}