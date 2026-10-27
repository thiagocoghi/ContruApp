# Progresso — EnginApp

> Status do desenvolvimento em relação ao planejamento do [`project.md`](project.md).
> Atualizado em: 27/10/2026.

## 📊 Resumo rápido

| Área | Status |
| --- | --- |
| Estrutura de pastas e arquivos base | ✅ Concluído |
| Ambiente Flutter (SDK, create, pub get, analyze, test) | ✅ Concluído |
| Decisão vector store (sqlite-vec vs ObjectBox) | ⏳ Pendente |
| Etapa 1 — MVP Diário de Obra por Voz | ✅ Código concluído (37 testes) — falta build em dispositivo |
| SLM on-device — Qwen 2.5 1.5B (motor, orquestrador, instalação automática + UI) | ✅ Código concluído — falta validar em aparelho |
| Build Android (APK release) | ✅ Gerado — 214 MB (falta instalar em aparelho) |
| Etapas 2 a 5 | ⬜ Não iniciadas |

## ✅ Concluído

### Estrutura do projeto (infraestrutura inicial)

- [x] Leitura e análise do PRD (`project.md`)
- [x] Definição da arquitetura: **feature-first + Clean Architecture**, camadas em português (`dominio` / `dados` / `apresentacao`)
- [x] Criação da árvore de diretórios em `lib/` (102 pastas):
  - [x] `lib/app/` — ponto de entrada, rotas por Etapa
  - [x] `lib/core/` — dominio, dados (SQLite, vetores), apresentacao, infra (FFI, permissões), di
  - [x] `lib/modulos/` — as 5 Etapas do roadmap (`diario_obra`, `calculadora`, `blueprint`, `normas`, `seguranca`)
  - [x] `lib/motor_ia/` — interfaces de domínio + dados (whisper, slm, visao, rag)
- [x] Diretórios de suporte: `assets/`, `native/`, `test/`, `docs/` (84 `.gitkeep` para versionamento)
- [x] Arquivos base:
  - [x] `pubspec.yaml` (dependências do stack validadas)
  - [x] `analysis_options.yaml`
  - [x] `.gitignore` (exclui modelos .gguf/.tflite/.onnx ~2,5 GB)
  - [x] `README.md` (mapa da estrutura + roadmap)
  - [x] `progress.md` (este arquivo)

### Ambiente de desenvolvimento

- [x] Flutter SDK instalado (3.47.8 stable / Dart 3.13.7)
- [x] `flutter create .` executado — plataformas geradas (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`)
- [x] `flutter pub get` — 14 dependências resolvidas
- [x] `flutter analyze` — **No issues found**
- [x] `flutter test` — **All tests passed** (smoke test do `BuildSapApp`)
- [x] `test/widget_test.dart` ajustado ao app real (substitui o template do contador)
- [x] App renomeado para **EnginApp** (pubspec `engin_app`, título do app, label Android, nome iOS, imports e testes); applicationId `br.buildsap.buildsap_mobile` mantido

---

## 🚧 Em andamento / Pendente

### Decisão técnica aberta

- [ ] Escolher a vector store para o RAG local: **`sqlite-vec` ou `ObjectBox`** (Seção 2.1 do PRD) — comentada no `pubspec.yaml`
- [x] ~~Runtime do SLM: MediaPipe ou llama.cpp~~ → **`llamadart` (llama.cpp)**
- [ ] Componente Apple do llama.cpp (`llamadart_llama_cpp_flutter`) — só necessário para build iOS

### 📋 Etapa 1 — Diário de Obra por Voz (`ObraVoice Engine`) — MVP

- [x] STT on-device com `whisper.cpp` — plugin `whisper_ggml` (bindings nativos Android/iOS/Windows; modelo baixado 1ª vez e cacheado no aparelho)
- [x] Captura de áudio WAV 16 kHz mono (`record`) com permissão explicada ao usuário
- [x] Pipeline `áudio → texto → RDO estruturado` (`MontarDiarioPorVoz`)
- [x] Extração de entidades determinística em PT-BR: clima, efetivo, materiais, ocorrências e prazos (`ExtratorRdoRegras`, com negações: "sem chuva", "não houve atraso")
- [x] Geração do RDO estruturado (JSON) e exportação em PDF (fonte Roboto embarcada para acentos do PT-BR)
- [x] Compartilhamento via WhatsApp/E-mail (`share_plus`)
- [x] UI completa: obras → diários da obra → gravação por voz → preview do RDO → detalhe + compartilhar
- [x] Esquema SQLite inicial (Seção 4: `obras`, `diarios_obra`, `materiais`) com DAOs, índices e serialização JSON
- [x] Testes da Etapa 1 e do motor de IA — **37 testes** (extrator por regras,
      extrator por SLM, cascata do orquestrador, cubit e banner de
      instalação, serialização, PDF, pipeline, cadastro de obra, smoke test)

### 🤖 SLM on-device — Qwen 2.5 1.5B (início da inclusão)

- [x] Escolha do runtime: **`llamadart`** (llama.cpp com runtime nativo
      resolvido por build hook — sem toolchain C++), em vez de MediaPipe/FFI
      manual. Componente iOS: `llamadart_llama_cpp_flutter` (pendente)
- [x] Contrato `InferenciaSlm` (`motor_ia/dominio/interfaces/`) — app
      testável sem o runtime nativo
- [x] `EngineQwen` (`motor_ia/dados/slm/`): Qwen2.5-1.5B-Instruct Q4_K_M
      (~1 GB), download sob demanda na 1ª execução + cache do pacote,
      contexto 2048 tokens, CPU/Metal automático, `preparar` idempotente
- [x] `OrquestradorIa` (`motor_ia/orquestrador_ia.dart`): cascata
      **SLM → regras determinísticas** — sem modelo pronto, JSON inválido,
      resposta vazia ou qualquer erro, cai para `ExtratorRdoRegras`; o fluxo
      de gravação nunca quebra
- [x] `ExtratorRdoIa`: instrução PT-BR com schema JSON do RDO + parser
      tolerante (cercas de código, textos extras, quantidades como string)
- [x] Pipeline plumbado: `MontarDiarioPorVoz` ganhou `extratorIa` opcional;
      DI instancia `OrquestradorIa(EngineQwen())`
- [x] `INTERNET` no `AndroidManifest.xml` (download dos modelos)
- [x] Scripts: `native/scripts/baixar_modelo_qwen.sh` (download manual com
      retomada e validação de tamanho) e
      `native/scripts/teste_inferencia.dart` (smoke test real ponta a ponta)
- [x] Smoke test real no desktop (Windows), via
      `dart run native/scripts/teste_inferencia.dart`: download de 1,04 GB ✓,
      carga do modelo 41,5s (1ª vez) / 3,6s (cache) e extração de ~5s por RDO
      em CPU — saída extraída corretamente (clima, efetivo, materiais,
      ocorrência)
- [x] **Instalação automática da LLM**: `PreparacaoIaCubit` nasce na DI junto
      com o app e dispara `orquestradorIa.preparar()` na inicialização — na
      1ª execução baixa e configura o modelo, nas seguintes aproveita o cache
- [x] **UI de download** (`BannerInstalacaoIa` no topo da tela inicial):
      barra de progresso com % ("Baixando o modelo Qwen 2.5 1.5B — X% de
      ~1 GB"), estado "Carregando o modelo na memória…", aviso de falha com
      botão "Tentar de novo"; some quando a IA fica pronta
- [x] Testes da UI: 5 do `PreparacaoIaCubit` (progresso, falha + retry,
      cache, concorrência) e 2 do banner (progresso/ocultação e erro/retry)
- [ ] Validar em aparelho Android: download, RAM e tempo de inferência
- [ ] iOS: `llamadart` exige deployment target **16.4+** (PRD prevê iOS 15+)
      — decidir entre subir o mínimo ou outro runtime
- [x] Extração via SLM (Gemma 2B / Qwen 1.5B) — implementada por
      `ExtratorRdoIa` atrás de `ExtratorEntidadesAsync`, com cascata para as
      regras no `OrquestradorIa`
- [x] Integração do SLM on-device — **Qwen 2.5 1.5B** via `llamadart`
      (llama.cpp). Pendências: UI de download e validação em aparelho

**Pendências de execução da Etapa 1 (fora do código):**

- [x] Instalar o Android SDK e gerar o APK (`flutter build apk --release`)
      — **`build/app/outputs/flutter-apk/app-release.apk`, 214 MB**, minSdk 29
      (Android 10, conforme PRD), 3 ABIs (arm64-v8a, armeabi-v7a, x86_64)
      com `libllama.so`/`libwhisper.so` embutidos. O tamanho inicial era
      330 MB: o runtime LiteRT-LM (~30 MB por ABI) que o app não usa foi
      removido via `hooks.user_defines.llamadart` no `pubspec.yaml`
      (necessário `flutter clean` após a mudança)
- [ ] Observação: `armeabi-v7a` (32 bits) não recebe as libs do llama.cpp —
      em aparelho 32 bits o SLM não carrega e a cascata cai nas regras
- [ ] Testar em dispositivo real: permissão de microfone, gravação, download do modelo whisper (~75 MB) e compartilhamento
- [ ] Build iOS (requer macOS + Xcode)

### 🧮 Etapa 2 — Calculadora Inteligente (`CalcObra AI`)

- [ ] Conversão de linguagem natural em rotinas matemáticas determinísticas
- [ ] Tabelas de rendimento de materiais
- [ ] Relatório de insumos com margem de perda (5%–15%)

### 📐 Etapa 3 — Leitor de Projetos (`BlueprintSnap AI`)

- [ ] Correção de perspectiva e otimização de contraste
- [ ] OCR local de cotas, legendas e tabelas (ML Kit)
- [ ] Leitura de áreas por demarcadores na tela
- [ ] Cruzamento de quantitativos com a Etapa 2

### 📖 Etapa 4 — Assistente de Normas (`NR-Master AI`)

- [ ] Motor RAG 100% on-device
- [ ] Base de normas vetorizada (NR-10/12/18/35, NBR 6118…)
- [ ] Chat com referências a itens/parágrafos
- [ ] Alertas contextuais de EPIs e exigências legais

### 🦺 Etapa 5 — Auditoria por Câmera (`SiteSafety Vision`)

- [ ] Pipeline de visão (YOLOv8-Nano / ONNX Mobile)
- [ ] Detecção de EPIs (capacete, cinto, óculos, botas)
- [ ] Identificação de situações de risco
- [ ] Emissão de Auto de Infração vinculado ao RDO

---

## Próximo passo recomendado

Código da Etapa 1 + motor Qwen fechados ✅ — agora:

1. Instalar o APK gerado (`build/app/outputs/flutter-apk/app-release.apk`)
   num aparelho Android 10+ e validar gravação → transcrição → RDO → PDF,
   além do download automático da LLM (banner da tela inicial).
2. Medir em aparelho o download automático da LLM (banner da tela inicial) e
   o tempo de inferência — ou rodar antes o smoke test no desktop com
   `dart run native/scripts/teste_inferencia.dart`.
3. Depois, avançar para a **Etapa 2** (CalcObra AI) ou o RAG da Etapa 4.
