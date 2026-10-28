import 'package:engin_app/core/dominio/casos_de_uso/criar_obra.dart';
import 'package:engin_app/core/dominio/entidades/obra.dart';
import 'package:engin_app/core/dominio/erros/falha_dominio.dart';
import 'package:engin_app/core/dominio/repositorios/obra_repositorio.dart';
import 'package:engin_app/modulos/diario_obra/dominio/casos_de_uso/extrator_rdo_regras.dart';
import 'package:engin_app/modulos/diario_obra/dominio/casos_de_uso/montar_diario_por_voz.dart';
import 'package:engin_app/modulos/diario_obra/dominio/interfaces/transcritor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transcritor falso: devolve o texto ensaiado sem tocar no whisper.
class _TranscritorFalso implements Transcritor {
  _TranscritorFalso(this.texto);

  final String texto;

  @override
  Future<String> transcrever({
    required String caminhoAudio,
    String idioma = 'pt',
  }) async =>
      texto;
}

class _ObraRepositorioMemoria implements ObraRepositorio {
  final List<Obra> obras = [];

  @override
  Future<List<Obra>> listar() async => obras;

  @override
  Future<List<Obra>> listarAtivas() async =>
      obras.where((o) => o.estaAtiva).toList();

  @override
  Future<List<Obra>> listarArquivadas() async =>
      obras.where((o) => !o.estaAtiva).toList();

  @override
  Future<Obra?> porId(String id) async {
    for (final o in obras) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<void> salvar(Obra obra) async => obras.add(obra);

  @override
  Future<void> atualizar(Obra obra) async {
    final i = obras.indexWhere((o) => o.id == obra.id);
    if (i >= 0) obras[i] = obra;
  }

  @override
  Future<void> excluir(String id) async => obras.removeWhere(
        (o) => o.id == id,
      );
}

void main() {
  group('MontarDiarioPorVoz — pipeline áudio→texto→RDO', () {
    const textoFalso = 'Hoje trabalharam 8 pedreiros. '
        'Compramos 15 sacos de cimento. Estava nublado.';

    test('transforma a transcrição em RDO estruturado', () async {
      final caso = MontarDiarioPorVoz(
        transcritor: _TranscritorFalso(textoFalso),
        extrator: const ExtratorRdoRegras(),
      );

      final diario = await caso.executar(
        caminhoAudio: '/tmp/gravacao.wav',
        obraId: 'o1',
        agora: DateTime(2026, 10, 26, 17),
      );

      expect(diario.obraId, 'o1');
      expect(diario.id, isNotEmpty);
      expect(diario.data, DateTime(2026, 10, 26, 17));
      expect(diario.transcricaoRaw, textoFalso);
      expect(diario.clima, 'Nublado');
      expect(diario.efetivo, hasLength(1));
      expect(diario.efetivo.single.quantidade, 8);
      expect(diario.materiais.single.material.toLowerCase(), 'cimento');
      expect(diario.pdfPath, isNull);
    });

    test('falha com mensagem amigável quando a transcrição vem vazia', () async {
      final caso = MontarDiarioPorVoz(
        transcritor: _TranscritorFalso(''),
        extrator: const ExtratorRdoRegras(),
      );

      expect(
        () => caso.executar(caminhoAudio: '/tmp/a.wav', obraId: 'o1'),
        throwsA(isA<FalhaDominio>()),
      );
    });
  });

  group('CriarObra', () {
    test('normaliza campos e gera id local', () async {
      final repo = _ObraRepositorioMemoria();
      final caso = CriarObra(repo);

      final obra = await caso.executar(
        nome: '  Residencial Aurora  ',
        cliente: '   ',
        localizacao: 'Rua A',
      );

      expect(obra.nome, 'Residencial Aurora');
      expect(obra.cliente, isNull);
      expect(obra.localizacao, 'Rua A');
      expect(obra.id, isNotEmpty);
      expect(repo.obras, hasLength(1));
    });

    test('nome vazio é rejeitado pela UI antes de chegar aqui', () async {
      final repo = _ObraRepositorioMemoria();
      final caso = CriarObra(repo);

      await expectLater(
        caso.executar(nome: '   '),
        throwsA(isA<FalhaDominio>().having((e) => e.mensagem, 'mensagem', isNotEmpty)),
      );
    });
  });
}