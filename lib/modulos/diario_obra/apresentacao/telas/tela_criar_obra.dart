import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/obras_cubit.dart';

/// Cadastro de nova obra.
class TelaCriarObra extends StatefulWidget {
  const TelaCriarObra({super.key});

  @override
  State<TelaCriarObra> createState() => _TelaCriarObraState();
}

class _TelaCriarObraState extends State<TelaCriarObra> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _cliente = TextEditingController();
  final _localizacao = TextEditingController();
  DateTime _dataInicio = DateTime.now();
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _cliente.dispose();
    _localizacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _salvando = true);

    final ok = await context.read<ObrasCubit>().criar(
          nome: _nome.text,
          cliente: _cliente.text,
          localizacao: _localizacao.text,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _salvando = false);
      final erro = context.read<ObrasCubit>().state.erro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro ?? 'Erro ao salvar a obra.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova obra')),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data de início'),
              subtitle: Text(
                '${_dataInicio.day.toString().padLeft(2, '0')}/'
                '${_dataInicio.month.toString().padLeft(2, '0')}/'
                '${_dataInicio.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final selecionada = await showDatePicker(
                  context: context,
                  initialDate: _dataInicio,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (selecionada != null) {
                  setState(() => _dataInicio = selecionada);
                }
              },
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
                  : const Text('Salvar obra'),
            ),
          ],
        ),
      ),
    );
  }
}