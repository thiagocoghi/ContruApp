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
      child: Scaffold(
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
          },
          icon: const Icon(Icons.mic_outlined),
          label: const Text('Novo diário por voz'),
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
        onTap: () => Navigator.pushNamed(
          context,
          '/diario/detalhe',
          arguments: (obra: obra, diario: diario),
        ),
      ),
    );
  }
}