import 'package:engin_app/modulos/diario_obra/apresentacao/bloc/diarios_cubit.dart';
import 'package:engin_app/modulos/diario_obra/dominio/entidades/diario_obra.dart';
import 'package:engin_app/modulos/diario_obra/dominio/repositorios/diario_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório em memória que registra as chamadas, para provar que editar a
/// transcrição não mexe nos demais campos.
class _DiarioRepositorioFake implements DiarioRepositorio {
  final List<DiarioObra> diarios = [];
  final List<String> atualizacoesDeTranscricao = [];
  final List<String> excluidos = [];

  /// Simula falha de armazenamento na exclusão.
  bool falharAoExcluir = false;

  @override
  Future<List<DiarioObra>> listarPorObra(String obraId) async =>
      diarios.where((d) => d.obraId == obraId).toList();

  @override
  Future<DiarioObra?> porId(String id) async {
    for (final d in diarios) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<void> salvar(DiarioObra diario) async => diarios.add(diario);

  @override
  Future<void> registrarPdf({required String id, required String caminhoPdf}) async {
    final i = diarios.indexWhere((d) => d.id == id);
    if (i >= 0) diarios[i] = diarios[i].copiarCom(pdfPath: caminhoPdf);
  }

  @override
  Future<void> atualizarTranscricao({
    required String id,
    required String texto,
  }) async {
    atualizacoesDeTranscricao.add(texto);
    final i = diarios.indexWhere((d) => d.id == id);
    if (i >= 0) {
      diarios[i] = diarios[i].copiarCom(transcricaoRaw: texto);
    }
  }

  @override
  Future<void> excluir(DiarioObra diario) async {
    if (falharAoExcluir) throw const FileSystemExceptionMock();
    excluidos.add(diario.id);
    diarios.removeWhere((d) => d.id == diario.id);
  }
}

DiarioObra _diario({String id = 'd1'}) => DiarioObra(
      id: id,
      obraId: 'o1',
      data: DateTime(2026, 10, 27),
      transcricaoRaw: 'Trabalharam 8 pedreiros em outubro.',
      clima: 'Nublado',
      efetivo: const [EfetivoItem(funcao: 'Pedreiro', quantidade: 8)],
      ocorrencias: const ['Entrega de aço atrasada'],
      pdfPath: '/tmp/rdo.pdf',
    );

void main() {
  group('DiariosCubit — correção de transcrição', () {
    test('salva o texto corrigido sem tocar nos campos extraídos', () async {
      final repo = _DiarioRepositorioFake()..diarios.add(_diario());
      final cubit = DiariosCubit(repositorio: repo, obraId: 'o1');
      await cubit.carregar();

      final ok = await cubit.atualizarTranscricao(
        diario: repo.diarios.single,
        texto: '  Trabalharam 8 pedreiros em outubro (corrigido).  ',
      );

      expect(ok, isTrue);
      expect(repo.atualizacoesDeTranscricao, ['Trabalharam 8 pedreiros em outubro (corrigido).']);

      final salvo = repo.diarios.single;
      expect(salvo.transcricaoRaw, 'Trabalharam 8 pedreiros em outubro (corrigido).');
      // Os dados lidos da fala permanecem — a edição é só do texto bruto.
      expect(salvo.clima, 'Nublado');
      expect(salvo.efetivo.single.quantidade, 8);
      expect(salvo.ocorrencias, ['Entrega de aço atrasada']);
      expect(salvo.pdfPath, '/tmp/rdo.pdf');
      expect(cubit.state.status, StatusDiarios.pronto);

      await cubit.close();
    });

    test('transcrição vazia é recusada e não grava nada', () async {
      final repo = _DiarioRepositorioFake()..diarios.add(_diario());
      final cubit = DiariosCubit(repositorio: repo, obraId: 'o1');
      await cubit.carregar();

      final ok = await cubit.atualizarTranscricao(
        diario: repo.diarios.single,
        texto: '   ',
      );

      expect(ok, isFalse);
      expect(repo.atualizacoesDeTranscricao, isEmpty);
      expect(repo.diarios.single.transcricaoRaw,
          'Trabalharam 8 pedreiros em outubro.');
      expect(cubit.state.status, StatusDiarios.erro);

      await cubit.close();
    });
  });

  group('DiariosCubit — exclusão do relatório', () {
    test('apaga o RDO e volta o estado para vazio', () async {
      final repo = _DiarioRepositorioFake()..diarios.add(_diario());
      final cubit = DiariosCubit(repositorio: repo, obraId: 'o1');
      await cubit.carregar();
      expect(cubit.state.status, StatusDiarios.pronto);

      final ok = await cubit.excluir(repo.diarios.single);

      expect(ok, isTrue);
      expect(repo.excluidos, ['d1']);
      expect(repo.diarios, isEmpty);
      expect(cubit.state.status, StatusDiarios.vazio);

      await cubit.close();
    });

    test('falha do repositório vira estado de erro, não exceção', () async {
      final repo = _DiarioRepositorioFake()
        ..diarios.add(_diario())
        ..falharAoExcluir = true;
      final cubit = DiariosCubit(repositorio: repo, obraId: 'o1');
      await cubit.carregar();

      final ok = await cubit.excluir(repo.diarios.single);

      expect(ok, isFalse);
      expect(repo.diarios, hasLength(1), reason: 'nada foi apagado');
      expect(cubit.state.status, StatusDiarios.erro);
      expect(cubit.state.erro, isNotNull);

      await cubit.close();
    });
  });
}

/// Exceção de arquivo usada para simular falha de disco.
class FileSystemExceptionMock implements Exception {
  const FileSystemExceptionMock();
}