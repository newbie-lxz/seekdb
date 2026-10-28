#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v16
stop_server
start_server before
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-collation-corpus.sql > results/v16-base-collation.txt 2> results/v16-base-collation.err
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-props-corpus.sql > results/v16-base-props.txt 2> results/v16-base-props.err
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-merge-corpus.sql > results/v16-base-merge.txt 2> results/v16-base-merge.err
python3 /home/chenyiting/fts-snapshot.py v16-base
stop_server
start_server v16
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v12.result < /home/chenyiting/fts-hot-path-v12.test
echo PASS_V15_REGRESSION
for spec in "props v16-base-props" "collation v16-base-collation" "merge v16-base-merge" "beng v8-base-beng" "v4 v4-base-corpus" "bmp v5-base-bmp"; do
 read -r corpus base <<< "$spec"
 mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-$corpus-corpus.sql > results/v16-$corpus.txt 2> results/v16-$corpus.err
 cmp results/$base.txt results/v16-$corpus.txt
 cmp results/$base.err results/v16-$corpus.err
 echo PASS_V15_$corpus
done
python3 /home/chenyiting/fts-snapshot.py v16-after
for q in cn beng mixed content; do cmp results/v16-base-$q.tsv results/v16-after-$q.tsv; done
echo PASS_V15_IDS_SCORES
for label in v15 v16 v16 v15; do
 stop_server
 start_server "$label"
 SKIP_LOAD=1 SAMPLES=5 QUERY_ROUNDS=600 LABEL="$label-skip-abba" OUTPUT=$PWD/results/v16-$label-skip-abba.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_V16_ABBA_$label
done
stop_server
start_server v16
echo PASS_V16_COMPLETE
