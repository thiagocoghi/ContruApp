# Documento de Especificação de Projeto (PRD) & Arquitetura
## Nome do Projeto: **BuildSAP Mobile** (Suíte Integrada de Gestão de Obras com IA On-Device)

---

## 1. Visão Geral do Produto

O **BuildSAP Mobile** é uma suíte modular de produtividade e gestão para o setor de Construção Civil e Serviços de Campo. O produto foi concebido sob o conceito de *ERP Mobile-First Offline*, unindo a robustez operacional de sistemas estilo SAP com a agilidade de um assistente inteligente rodando 100% no dispositivo do usuário (*On-Device AI*).

### Diferenciais Estratégicos
* **Privacidade Absoluta:** Nenhuma informação do canteiro de obras, projeto ou cliente é enviada para servidores de IA em nuvem.
* **Operação Offline-First:** Funciona em subsolos, áreas rurais e canteiros de obras sem cobertura de rede móvel.
* **Custo Zero de Ingerência por Token:** Elimina custos de APIs pagas (OpenAI/Anthropic) por requisição.
* **Modularidade Gradual:** Evolução do aplicativo dividida em 5 fases contínuas.

---

## 2. Arquitetura Técnica & Tech Stack

### 2.1. Camada de Aplicação Mobile (Client)
* **Framework:** Flutter (Dart) — Alta performance, suporte nativo a rotinas em C/C++ via FFI (Foreign Function Interface) e UI consistente em Android/iOS.
* **Gerenciamento de Estado:** BLoC / Cubit (para garantir previsibilidade em sistemas complexos estilo ERP).
* **Banco de Dados Local:** SQLite + Room/Isar (para persistência de dados estruturados e tabelas relacionais de estoque, diários e medições).
* **Armazenamento de Vetores Local (Vector Store):** `sqlite-vec` ou `ObjectBox` para busca semântica em normas e documentos (RAG local).

### 2.2. Motor de IA & Inferência On-Device
* **Processamento de Linguagem Natural (SLM):**
  * *Motor:* `MediaPipe LLM Inference API` (Google) ou `llama.cpp` compilado via C++ FFI.
  * *Modelos Base:* **Gemma 2B / Qwen 2.5 1.5B Instruct / Llama 3.2 1B-3B** (quantizados em INT4 / GGUF Q4_K_M).
* **Reconhecimento e Transcrição de Voz (STT):**
  * *Motor:* `Whisper.cpp` (versão C++ ultra-leve do OpenAI Whisper).
  * *Modelo:* `Whisper Tiny` ou `Base` (quantizado para PT-BR).
* **Visão Computacional & OCR Local:**
  * *Motor:* Google ML Kit (OCR e Detecção de Objetos) + `YOLOv8-Nano` / `MobileNetV4` (executados via TensorFlow Lite / ONNX Runtime Mobile).

---

## 3. Roadmap de Desenvolvimento por Etapas (Fases do Projeto)

---

### 📋 ETAPA 1: Diário de Obra por Voz (`ObraVoice Engine`)

#### Objetivo
Permitir que mestres de obra e engenheiros gravem relatórios diários apenas falando, gerando dados estruturados e relatórios formais em PDF.

#### Funcionalidades Principais
1. Captura de áudio e transcrição offline em tempo real (Whisper.cpp).
2. Extração inteligente de entidades (Categorias: Mão de Obra, Materiais Utilizados, Clima, Ocorrências, Prazos).
3. Geração automática do Relatório Diário de Obra (RDO) padronizado.
4. Exportação em PDF e compartilhamento instantâneo via WhatsApp/E-mail.

#### Estrutura do Pipeline da Etapa 1

[ Áudio falado ] ──► (Whisper.cpp Local) ──► [ Texto Bruto ]
│
▼
[ RDO Estruturado (JSON/PDF) ] ◄── (SLM Gemma 2B) ──┘

---

### 🧮 ETAPA 2: Calculadora Inteligente de Reforço e Estruturas (`CalcObra AI`)

#### Objetivo
Fornecer cálculos de engenharia civil e estimativas de insumos via linguagem natural ou formulários ágeis.

#### Funcionalidades Principais
1. Processador de comandos de voz e texto (Ex: *"Calcula o traço de concreto para uma laje de 50m² com 12cm de espessura"*).
2. Conversão da intenção do usuário em rotinas matemáticas determinísticas de engenharia (evitando alucinações de cálculo pela IA).
3. Tabelas de rendimento de materiais (Cimento, Areia, Brita, Aço, Argamassa, Tijolos/Blocos).
4. Relatório de consumo de insumos com margem de perda configurável (5% a 15%).

---

### 📐 ETAPA 3: Leitor de Projetos & Quantitativos (`BlueprintSnap AI`)

#### Objetivo
Extrair metadados, cotas e tabelas de quantitativos a partir de fotos de plantas baixas e projetos impressos.

#### Funcionalidades Principais
1. Escaneamento com correção de perspectiva e otimização de contraste da imagem.
2. OCR avançado local para leitura de cotas, legendas e tabelas em desenhos técnicos.
3. Leitura e cálculo de áreas por demarcadores visuais na tela do smartphone.
4. Cruzamento dos quantitativos extraídos com o módulo da Calculadora (Etapa 2) para orçamento automático de materiais.

---

### 📖 ETAPA 4: Assistente de Normas Técnicas e Segurança (`NR-Master AI`)

#### Objetivo
Disponibilizar um consultor técnico offline de NBRs (ABNT) e NRs (Normas Regulamentadoras de Segurança).

#### Funcionalidades Principais
1. Motor RAG (Retrieval-Augmented Generation) 100% On-Device.
2. Base de conhecimento embarcada e vetorizada localmente (NR-10, NR-12, NR-18, NR-35, NBR 6118, etc.).
3. Chat interativo com referências diretas a itens e parágrafos das normas oficiais.
4. Alertas contextuais sobre exigências legais e EPIs obrigatórios para cada etapa registrada na obra.

---

### 🦺 ETAPA 5: Auditoria de Segurança e Riscos por Câmera (`SiteSafety Vision`)

#### Objetivo
Identificar não-conformidades de segurança do trabalho no canteiro em tempo real usando a câmera do dispositivo.

#### Funcionalidades Principais
1. Análise do feed da câmera via modelo de visão leve (YOLOv8-Nano / ONNX).
2. Detecção automática de uso de EPIs (Capacete, Cinto de Segurança, Óculos, Botas).
3. Identificação de situações de risco (Fiação exposta, falta de guarda-corpo, andaimes desprovidos de trava).
4. Emissão automática de Auto de Infração/Ressalva no módulo de Diário de Obra (Etapa 1).

---

## 4. Estrutura de Banco de Dados Local (Esquema Simplificado)

```sql
-- Tabela de Obras
CREATE TABLE obras (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    cliente TEXT,
    localizacao TEXT,
    data_inicio DATE
);

-- Tabela de Diários de Obra (RDO)
CREATE TABLE diarios_obra (
    id TEXT PRIMARY KEY,
    obra_id TEXT REFERENCES obras(id),
    data DATE NOT NULL,
    transcricao_raw TEXT,
    clima TEXT,
    efetivo_json TEXT,
    ocorrencias_json TEXT,
    pdf_path TEXT
);

-- Tabela de Materiais e Estoque
CREATE TABLE materiais (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    unidade TEXT NOT NULL,
    quantidade_estoque REAL DEFAULT 0
);
```

---

## 5. Requisitos Mínimos de Hardware do Dispositivo

Sistema Operacional: Android 10+ (API Level 29) ou iOS 15+.

Processador: Snapdragon 778G / Dimensity 900 ou superior (com suporte a instruções NPU/NEON).

Memória RAM Mínima: 4 GB RAM (Recomendado: 6 GB ou mais para execuções suaves do SLM).

Armazenamento: 2.5 GB livres (para armazenamento dos modelos quantizados).

---

## 6. Próximos Passos de Execução (Início do MVP - Etapa 1)

Configuração do Ambiente Flutter: Inicialização do repositório base com arquitetura limpa (Clean Architecture).

Compilação do Whisper.cpp: Integração da biblioteca de áudio C++ via Flutter FFI no Android/iOS.

Integração do Gemma 2B / Qwen 1.5B: Testes de inferência local via MediaPipe LLM Inference.

Design da UI do Diário de Obra: Criação do fluxo de gravação de áudio e visualização do relatório RDO.

Aqui está o planejamento e documento do projeto **BuildSAP Mobile**. Fique à vontade para copiar ou adaptar a estrutura conforme necessário para dar início ao desenvolvimento do MVP!

---