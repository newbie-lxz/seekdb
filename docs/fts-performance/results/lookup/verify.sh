#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v5
stop_server
start_server v5
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v4.result < /home/chenyiting/fts-hot-path-v4.test
echo PASS_V5_REGRESSION
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-v4-corpus.sql > results/v5-corpus.txt 2> results/v5-corpus.err
cmp results/v4-base-corpus.txt results/v5-corpus.txt
cmp results/v4-base-corpus.err results/v5-corpus.err
echo PASS_V5_CORPUS_450
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-bmp-corpus.sql > results/v5-bmp.txt 2> results/v5-bmp.err
cmp results/v5-base-bmp.txt results/v5-bmp.txt
cmp results/v5-base-bmp.err results/v5-bmp.err
echo PASS_V5_BMP_3968
python3 /home/chenyiting/fts-snapshot.py v5-after-same-data
for q in cn beng mixed content; do cmp results/v5-base-same-data-$q.tsv results/v5-after-same-data-$q.tsv; done
echo PASS_V5_IDS_SCORES
LABEL=v5 OUTPUT=$PWD/results/v5-full.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
echo PASS_V5_FULL_BENCH
stop_server
start_server before
LABEL=v5-before OUTPUT=$PWD/results/v5-before-full.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
echo PASS_V5_BEFORE_FULL_BENCH
stop_server
start_server v5
echo PASS_V5_COMPLETE
