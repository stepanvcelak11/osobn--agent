#!/usr/bin/env bash
# Ověří gramatiky agenta skutečným parserem llama.cpp (stejná verze jako v aplikaci).
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
C="$B/grammar-check"
"$C" "$G/agent.gbnf" \
 '+{"type":"answer","text":"Ahoj, mám \"to\" hotové.\n"}' \
 '+{"type":"ask","text":"Kdy?"}' \
 '+{"type":"tool","name":"create_reminder","args":{"title":"Zavolat doktorovi","when":"zítra v 8"}}' \
 '+{"type":"tool","name":"create_event","args":{"title":"Schůzka","start":"v pátek ve 14","duration_minutes":90,"location":"kancelář"}}' \
 '+{"type":"tool","name":"create_task","args":{"title":"A","priority":"high"}}' \
 '+{"type":"tool","name":"undo_last","args":{}}' \
 '+{"type":"tool","name":"list_agenda","args":{"range":"next_week"}}' \
 '-{"type":"tool","name":"rm_rf","args":{}}' \
 '-{"type":"tool","name":"create_reminder","args":{"title":"x"}}' \
 '-{"type": "answer","text":"x"}' \
 '-{"type":"answer","text":"x"} navíc'
"$C" "$G/capture.gbnf" '+{"type":"tool","name":"create_note","args":{"text":"x"}}' '-{"type":"answer","text":"x"}' '+{"type":"ask","text":"?"}'
"$C" "$G/answer.gbnf" '+{"type":"answer","text":"Dnes máš 2 úkoly."}' '-{"type":"ask","text":"x"}'
"$C" "$G/agent.gbnf" \
 '+{"type":"tool","name":"set_timer","args":{"duration":"10 minut","label":"Čaj"}}' \
 '+{"type":"tool","name":"set_alarm","args":{"when":"zítra v 6:30"}}' \
 '+{"type":"tool","name":"stopwatch","args":{"action":"lap"}}' \
 '-{"type":"tool","name":"stopwatch","args":{"action":"explode"}}'
"$C" "$G/summary.gbnf" \
 '+{"title":"Fotosyntéza","summary":"Přednáška o \"světle\".","points":["A","B"],"tasks":[]}' \
 '-{"title":"x","summary":"y","points":"A","tasks":[]}'
echo "Gramatiky OK"
