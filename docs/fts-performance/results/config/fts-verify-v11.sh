#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
stop_server
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v11
start_server v11
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v7.result < /home/chenyiting/fts-hot-path-v7.test
echo PASS_V11_REGRESSION
for spec in "props v11-v10-props" "beng v8-base-beng" "merge v11-base-merge" "v4 v4-base-corpus"; do
 read -r corpus base <<< "$spec"
 file=/home/chenyiting/fts-$corpus-corpus.sql
 if [[ "$corpus" == "v4" ]]; then file=/home/chenyiting/fts-v4-corpus.sql; fi
 mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < "$file" > results/v11-$corpus.txt 2> results/v11-$corpus.err
 cmp results/$base.txt results/v11-$corpus.txt
 cmp results/$base.err results/v11-$corpus.err
 echo PASS_V11_$corpus
done
python3 /home/chenyiting/fts-snapshot.py v11-after
for q in cn beng mixed content; do cmp results/v11-base-$q.tsv results/v11-after-$q.tsv; done
echo PASS_V11_IDS_SCORES
for label in v10 v11 v11 v10; do
 stop_server
 start_server "$label"
 LABEL="$label-stable" SKIP_LOAD=1 SAMPLES=5 QUERY_ROUNDS=600 OUTPUT=$PWD/results/v11-$label-stable.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_V11_STABLE_$label
done
for label in before v11; do
 stop_server
 start_server "$label"
 LABEL="$label-full" OUTPUT=$PWD/results/v11-$label-full.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_V11_FULL_$label
done
echo PASS_V11_COMPLETE
