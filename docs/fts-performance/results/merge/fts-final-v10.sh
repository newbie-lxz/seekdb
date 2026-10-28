#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
for label in before v10; do
 stop_server
 start_server "$label"
 LABEL="$label-final-full" OUTPUT="$PWD/results/v10-$label-final-full.txt" bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_FINAL_FULL_$label
done
echo PASS_FINAL_FULL_COMPLETE
