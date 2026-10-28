import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/registrador_dependencias.dart';
import '../../../../core/dominio/entidades/obra.dart';
import '../../dominio/entidades/diario_obra.dart';
import '../bloc/diarios_cubit.dart';

/// Detalhe do RDO: dados estruturados + exportação em PDF com
/// compartilhamento (WhatsApp/e-mail) — Etapa 1, itens 3-4.
///
/// Também é a tela de correção: a transcrição pode ser editada quando o
/// whisper errou uma palavra, e o relatório pode ser apagado.
class TelaDetalheDiario extends StatefulWidget {
  const TelaDetalheDiario({super.key, required this.obra, required this.diario});

  final Obra obra;
  final DiarioObra diario;

  @override
  State<TelaDetalheDiario> createState() => _TelaDetalheDiarioState();
}

class _TelaDetalheDiarioState extends State<TelaDetalheDiario> {
  bool _exportando = false;

  /// Cópia editável: a tela reflete a transcrição corrigida sem precisar
  /// recarregar a rota.
  late DiarioObra _diario = widget.diario;

  /// Rota de detalhe é empilhada pelo Navigator raiz, então não herda o
  /// `DiariosCubit` da lista — esta tela cria o seu próprio (só para editar
  /// e excluir) e o descarta ao sair.
  late final DiariosCubit _cubit = DiariosCubit(
    repositorio: RegistrarDependencias.instancia.diarios,
    obraId: widget.obra.id,
  );

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _exportarECompartilhar() async {
    setState(() => _exportando = true);
    try {
      final caminho = await RegistrarDependencias.instancia.exportarPdf
          .executar(obra: widget.obra, diario: _diario);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(caminho)],
        subject: 'RDO — ${widget.obra.nome}',
        text: 'Relatório Diário de Obra — ${widget.obra.nome}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao gerar o PDF do RDO.')),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  /// Corrige a transcrição. Como o PDF embute esse texto, um relatório já
  /// gerado é regenerado na hora — senão o arquivo ficaria com a versão
  /// antiga e o RDO na tela com a nova.
  Future<void> _editarTranscricao() async {
    final controlador = TextEditingController(text: _diario.transcricaoRaw);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar transcrição'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          minLines: 6,
          maxLines: 14,
          decoration: const InputDecoration(
            hintText: 'Corrija as palavras que o reconhecimento errou.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final texto = controlador.text;
    final salvo = await _cubit.atualizarTranscricao(
      diario: _diario,
      texto: texto,
    );
    if (!mounted) return;

    if (!salvo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cubit.state.erro ?? 'Erro ao salvar.')),
      );
      return;
    }

    setState(() => _diario = _diario.copiarCom(transcricaoRaw: texto.trim()));

    // Regrava o PDF já existente para o arquivo acompanhar a correção.
    if (_diario.pdfPath != null) {
      try {
        await RegistrarDependencias.instancia.exportarPdf
            .executar(obra: widget.obra, diario: _diario);
      } catch (_) {
        // Sem espaço/permissão o RDO segue salvo; só o PDF não foi refeito.
      }
    }
  }

  Future<void> _excluir() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir este relatório?'),
        content: Text(
          'O RDO de ${DateFormat('dd/MM/yyyy').format(_diario.data)} e o PDF '
          'gerado a partir dele serão apagados definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final ok = await _cubit.excluir(_diario);
    if (!mounted) return;

    if (ok) {
      // true instrui a lista a recarregar ao voltar.
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cubit.state.erro ?? 'Erro ao excluir.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diario = _diario;
    final data = DateFormat('dd/MM/yyyy').format(diario.data);
    final efetivoTotal = diario.efetivo.fold<int>(0, (s, e) => s + e.quantidade);

    return Scaffold(
      appBar: AppBar(
        title: Text('RDO — $data'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ações do relatório',
            onSelected: (opcao) {
              switch (opcao) {
                case 'editar':
                  _editarTranscricao();
                case 'excluir':
                  _excluir();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'editar', child: Text('Editar transcrição')),
              PopupMenuItem(value: 'excluir', child: Text('Excluir relatório')),
            ],
          ),
        ],
      ),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Secao(
              titulo: 'Obra',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.obra.nome),
                  if (widget.obra.cliente != null)
                    Text('Cliente: ${widget.obra.cliente}',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (widget.obra.localizacao != null)
                    Text('Local: ${widget.obra.localizacao}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (diario.clima != null)
              _Secao(
                titulo: 'Clima',
                child: Text(diario.clima!),
              ),
            if (diario.efetivo.isNotEmpty)
              _Secao(
                titulo: 'Efetivo ($efetivoTotal pessoas)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in diario.efetivo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('${e.quantidade} — ${e.funcao}'),
                      ),
                  ],
                ),
              ),
            if (diario.materiais.isNotEmpty)
              _Secao(
                titulo: 'Materiais utilizados',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in diario.materiais)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${m.quantidade % 1 == 0 ? m.quantidade.toInt() : m.quantidade} '
                          '${m.unidade} de ${m.material}',
                        ),
                      ),
                  ],
                ),
              ),
            if (diario.ocorrencias.isNotEmpty)
              _Secao(
                titulo: 'Ocorrências',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final o in diario.ocorrencias)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $o'),
                      ),
                  ],
                ),
              ),
            if (diario.prazos.isNotEmpty)
              _Secao(
                titulo: 'Prazos e compromissos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in diario.prazos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $p'),
                      ),
                  ],
                ),
              ),
            _Secao(
              titulo: 'Transcrição original',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diario.transcricaoRaw,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _editarTranscricao,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Corrigir transcrição'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportando ? null : _exportarECompartilhar,
        icon: _exportando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.share_outlined),
        label: const Text('PDF / Compartilhar'),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}