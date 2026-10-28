import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dominio/entidades/obra.dart';
import '../bloc/obras_cubit.dart';

/// Cadastro e edição de obra — mesma tela nos dois casos: quando [obra] é
/// nula cria um registro novo, quando vem preenchida edita o existente.
class TelaFormObra extends StatefulWidget {
  const TelaFormObra({super.key, this.obra});

  /// Obra em edição; `null` significa cadastro.
  final Obra? obra;

  @override
  State<TelaFormObra> createState() => _TelaFormObraState();
}

class _TelaFormObraState extends State<TelaFormObra> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _cliente;
  late final TextEditingController _localizacao;
  late final TextEditingController _detalhes;
  late DateTime _dataInicio;
  DateTime? _dataFim;
  bool _salvando = false;

  bool get _editando => widget.obra != null;

  @override
  void initState() {
    super.initState();
    final obra = widget.obra;
    _nome = TextEditingController(text: obra?.nome ?? '');
    _cliente = TextEditingController(text: obra?.cliente ?? '');
    _localizacao = TextEditingController(text: obra?.localizacao ?? '');
    _detalhes = TextEditingController(text: obra?.detalhes ?? '');
    _dataInicio = obra?.dataInicio ?? DateTime.now();
    _dataFim = obra?.dataFim;
  }

  @override
  void dispose() {
    _nome.dispose();
    _cliente.dispose();
    _localizacao.dispose();
    _detalhes.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _salvando = true);

    final cubit = context.read<ObrasCubit>();
    final ok = _editando
        ? await cubit.editar(
            obra: widget.obra!,
            nome: _nome.text,
            cliente: _cliente.text,
            localizacao: _localizacao.text,
            detalhes: _detalhes.text,
            dataInicio: _dataInicio,
            dataFim: _dataFim,
          )
        : await cubit.criar(
            nome: _nome.text,
            cliente: _cliente.text,
            localizacao: _localizacao.text,
            detalhes: _detalhes.text,
            dataInicio: _dataInicio,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _salvando = false);
      final erro = cubit.state.erro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro ?? 'Erro ao salvar a obra.')),
      );
    }
  }

  Future<void> _escolherData({required bool fim}) async {
    final inicial = fim ? (_dataFim ?? DateTime.now()) : _dataInicio;
    final selecionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selecionada == null) return;
    setState(() {
      if (fim) {
        _dataFim = selecionada;
      } else {
        _dataInicio = selecionada;
      }
    });
  }

  String _formatar(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar obra' : 'Nova obra')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome da obra *',
                hintText: 'Ex.: Residencial Aurora — Blocos A e B',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cliente,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Cliente'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _localizacao,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Localização',
                hintText: 'Endereço do canteiro',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detalhes,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Anotações do engenheiro ou mestre de obra:\n'
                    'pendências, combinados, riscos, visitas...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            _LinhaData(
              rotulo: 'Data de início',
              valor: _formatar(_dataInicio),
              aoEscolher: () => _escolherData(fim: false),
            ),
            _LinhaData(
              rotulo: 'Data de fim',
              valor: _dataFim == null ? 'Não definida' : _formatar(_dataFim!),
              aoEscolher: () => _escolherData(fim: true),
              aoLimpar: _dataFim == null
                  ? null
                  : () => setState(() => _dataFim = null),
            ),
            if (!_editando)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'A data de fim pode ser preenchida depois, ao encerrar a '
                  'obra pela lista.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editando ? 'Salvar alterações' : 'Salvar obra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaData extends StatelessWidget {
  const _LinhaData({
    required this.rotulo,
    required this.valor,
    required this.aoEscolher,
    this.aoLimpar,
  });

  final String rotulo;
  final String valor;
  final VoidCallback aoEscolher;
  final VoidCallback? aoLimpar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(rotulo),
      subtitle: Text(valor),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (aoLimpar != null)
            IconButton(
              tooltip: 'Limpar data',
              icon: const Icon(Icons.clear),
              onPressed: aoLimpar,
            ),
          const Icon(Icons.calendar_today_outlined),
        ],
      ),
      onTap: aoEscolher,
    );
  }
}