#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
stop_server
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v10
start_server v10
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v7.result < /home/chenyiting/fts-hot-path-v7.test
echo PASS_V10_REGRESSION
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-merge-corpus.sql > results/v10-merge.txt 2> results/v10-merge.err
cmp results/v10-base-merge.txt results/v10-merge.txt
cmp results/v10-base-merge.err results/v10-merge.err
echo PASS_V10_MERGE_37
python3 /home/chenyiting/fts-snapshot.py v10-after-same-data
for q in cn beng mixed content; do cmp results/v10-base-same-data-$q.tsv results/v10-after-same-data-$q.tsv; done
echo PASS_V10_IDS_SCORES
LABEL=v10 OUTPUT=$PWD/results/v10-full.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
echo PASS_V10_FULL_BENCH
for label in v5 v10 v10 v5; do
 stop_server
 start_server "$label"
 LABEL="$label-stable" SKIP_LOAD=1 SAMPLES=5 QUERY_ROUNDS=1000 OUTPUT=$PWD/results/v10-$label-stable.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_V10_STABLE_$label
done
stop_server
start_server v10
echo PASS_V10_COMPLETE
