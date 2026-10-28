#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
stop_server
start_server v5
client_pids=()
for i in 1 2 3 4; do
 mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-v4-corpus.sql > results/v5-concurrent-$i.txt 2> results/v5-concurrent-$i.err &
 client_pids+=("$!")
done
for client_pid in "${client_pids[@]}"; do wait "$client_pid"; done
for i in 1 2 3 4; do
 cmp results/v4-base-corpus.txt results/v5-concurrent-$i.txt
 cmp results/v4-base-corpus.err results/v5-concurrent-$i.err
done
echo PASS_V5_CONCURRENT_1800
sha256sum bin/seekdb-v5 > results/v5-binary.sha256
sha256sum results/v5-base-bmp.* results/v5-bmp.* results/v5-*-same-data-*.tsv results/v5-concurrent-* > results/v5-correctness.sha256
echo PASS_FINAL_COMPLETE
