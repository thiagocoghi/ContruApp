# EnginApp

> App **EnginApp** — o documento [`project.md`](project.md) foi escrito com o
> nome de planejamento *BuildSAP Mobile*.

Suíte Integrada de Gestão de Obras com IA On-Device. ERP Mobile-First Offline
para o setor de Construção Civil e Serviços de Campo.

Especificação completa: [`project.md`](project.md).

## Stack (PRD Seção 2)

| Camada | Tecnologia |
| --- | --- |
| App | Flutter (Dart), Android 10+ / iOS 15+ |
| Estado | BLoC / Cubit |
| Banco local | SQLite (sqflite) |
| Vetores (RAG) | sqlite-vec **ou** ObjectBox (decisão pendente) |
| STT | `whisper.cpp` (FFI C++) — Whisper Tiny/Base PT-BR |
| SLM | `llama.cpp` via [`llamadart`](https://pub.dev/packages/llamadart) — **Qwen 2.5 1.5B Instruct** (GGUF Q4_K_M, ~1 GB, baixado na 1ª execução) |
| Visão/OCR | ML Kit + YOLOv8-Nano / MobileNetV4 (TFLite / ONNX) |

## Estrutura de pastas

Arquitetura limpa **feature-first**: cada Etapa do roadmap vira um módulo, e
dentro dele as camadas em português (`dominio` → `dados` → `apresentacao`).

```
lib/
├── main.dart                     # Bootstrap offline-first (banco + motor de IA)
├── app/                          # Composição do app: widget raiz, rotas, tema
├── core/                         # Código compartilhado entre todos os módulos
│   ├── dominio/                  # entidades, casos de uso, repositórios, erros
│   ├── dados/                    # SQLite (conexao, migracoes, daos), vetores, modelos
│   ├── apresentacao/             # widgets, tema e formatações reutilizáveis
│   ├── infra/                    # FFI (C++), permissões, utilitários
│   └── di/                       # registro de dependências
├── modulos/
│   ├── diario_obra/              # 📋 Etapa 1 — ObraVoice Engine (RDO por voz)
│   ├── calculadora/              # 🧮 Etapa 2 — CalcObra AI
│   ├── blueprint/                # 📐 Etapa 3 — BlueprintSnap AI
│   ├── normas/                   # 📖 Etapa 4 — NR-Master AI (RAG local)
│   └── seguranca/                # 🦺 Etapa 5 — SiteSafety Vision
└── motor_ia/                     # Motor de inferência on-device
    ├── orquestrador_ia.dart      # Cascata SLM (Qwen) → regras determinísticas
    ├── apresentacao/             # Instalação automática da LLM (cubit + banner)
    ├── dominio/interfaces/       # Contratos: InferenciaSlm (Transcritor/ Detector)
    └── dados/                    # whisper/ (STT), slm/ (EngineQwen), visao/, rag/
```

Cada módulo em `lib/modulos/<modulo>/` segue o mesmo padrão de camadas:

```
dominio/      entidades · casos_de_uso · reposititorios   (regras puras, sem Flutter)
dados/        modelos · fontes_locais · repositorios      (implementações + SQLite)
apresentacao/ bloc · telas · widgets                      (UI e estados Cubit/Bloc)
```

## Outros diretórios

- `assets/` — `fonts/` (Roboto para o PDF do RDO), `modelos/` (whisper, slm, visão;
  ~2,5 GB, fora do versionamento), `normas/` (base NR/NBR vetorizada),
  `templates/` (layout do RDO), `imagens/`.
- `native/` — scripts da área de IA: `baixar_modelo_qwen.sh` (download manual
  do GGUF com retomada) e `teste_inferencia.dart` (smoke test real da
  inferência Qwen).
- `test/` — espelha `lib/` (unitários de domínio, blocs e repositórios).
- `docs/` — notas de arquitetura e decisões técnicas.

## Primeiros passos

1. `flutter pub get`
2. `flutter analyze` e `flutter test` (37 testes: Etapa 1 + motor de IA)
3. Opcional — inferência real no desktop:
   `dart run native/scripts/teste_inferencia.dart`
3. Conectado a um aparelho Android 10+/iOS 15+: `flutter run`

> A plataforma já foi gerada com `flutter create . --org br.buildsap
> --project-name engin_app`.

## Status

Etapa 1 (Diário de Obra por Voz) com código completo e testado, e o motor do
SLM **Qwen 2.5 1.5B** já integrado (engine + orquestrador em cascata +
instalação automática com UI de progresso + scripts) — ver
[`progress.md`](progress.md) para o detalhe do que falta (build em dispositivo
e validação em aparelho).

## Integração contínua

O pipeline em [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em
cada push para `main`/`updates` e em cada pull request:

1. `flutter pub get` — dependências (Flutter 3.47.8 fixado);
2. `flutter analyze` — falha o pipeline em **qualquer** problema;
3. `flutter test` — suíte completa (37 testes: extratores, cascata do
   orquestrador, instalação da LLM, PDF, pipeline de voz e smoke test).

Assim nenhuma quebra de comportamento chega à `main` sem ser detectada.

## Roadmap (PRD Seção 3)

1. **Etapa 1 — Diário de Obra por Voz**: transcrição offline → entidades → RDO em PDF.
2. **Etapa 2 — Calculadora Inteligente**: intenção em linguagem natural → rotinas matemáticas determinísticas.
3. **Etapa 3 — Leitor de Projetos**: OCR + correção de perspectiva → quantitativos.
4. **Etapa 4 — NR-Master AI**: RAG 100% on-device com NBRs e NRs.
5. **Etapa 5 — SiteSafety Vision**: detecção de EPIs e riscos via câmera.