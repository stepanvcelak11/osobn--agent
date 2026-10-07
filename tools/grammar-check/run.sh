#!/usr/bin/env bash
# Ověří gramatiky Pocket Realm skutečným parserem llama.cpp (stejná verze jako v aplikaci).
# Použití: tools/grammar-check/run.sh <adresář s *.gbnf> <cesta k llama.cpp na tagu b11440>
set -euo pipefail
G="$1"; L="$2"; B="${3:-/tmp/llama-build}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cmake -S "$L" -B "$B" -DBUILD_SHARED_LIBS=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_COMMON=OFF -DGGML_NATIVE=OFF -DLLAMA_OPENSSL=OFF \
  -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$B" --target llama -j"$(nproc)" >/dev/null
g++ -std=c++17 -O1 "$HERE/check.cpp" -I"$L/src" -I"$L/include" -I"$L/ggml/include" \
  "$B/src/libllama.a" "$B/ggml/src/libggml.a" "$B/ggml/src/libggml-cpu.a" "$B/ggml/src/libggml-base.a" \
  -lpthread -fopenmp -o "$B/grammar-check"
bash "$HERE/cases.sh" "$B/grammar-check" "$G"
