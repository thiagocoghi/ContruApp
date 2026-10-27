#!/usr/bin/env bash
#
# Baixa o modelo Qwen 2.5 1.5B Instruct (GGUF, quantização Q4_K_M) para
# desenvolvimento local e para rodar o smoke test de inferência sem rede.
#
#   ./native/scripts/baixar_modelo_qwen.sh
#
# Destino: assets/modelos/slm/ (fora do versionamento e fora do bundle —
# ver .gitignore e pubspec.yaml). No aparelho o download é automático pela
# primeira carga do EngineQwen (fonte hf://), então este script é opcional.
set -euo pipefail

URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
TAMANHO_ESPERADO=1117320736 # bytes (Q4_K_M, ~1,04 GB)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/assets/modelos/slm"
DESTINO="$DIR/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"

mkdir -p "$DIR"

if [[ -f "$DESTINO" ]] && [[ "$(wc -c <"$DESTINO")" -eq "$TAMANHO_ESPERADO" ]]; then
  echo "Modelo já presente em $DESTINO"
  exit 0
fi

echo "Baixando Qwen2.5-1.5B-Instruct-Q4_K_M.gguf (~1 GB)..."
# -C - retoma um download interrompido; --fail não deixa erro 4xx virar "sucesso".
curl -L -C - --fail --progress-bar -o "$DESTINO" "$URL"

TAMANHO_REAL="$(wc -c <"$DESTINO")"
if [[ "$TAMANHO_REAL" -ne "$TAMANHO_ESPERADO" ]]; then
  echo "ERRO: tamanho inesperado ($TAMANHO_REAL bytes, esperado $TAMANHO_ESPERADO)." >&2
  echo "Remova o arquivo e execute o script novamente." >&2
  exit 1
fi

echo "OK: $DESTINO"
echo "Smoke test de inferência: dart run native/scripts/teste_inferencia.dart"
