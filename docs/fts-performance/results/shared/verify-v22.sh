#!/bin/bash
set -euo pipefail
grep -q "^PASS_BUILD_V22$" /home/chenyiting/fts-v22-build-driver.log
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v22
stop_server
start_server before
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --record --result-file=results/fts_hot_path_v19.result < /home/chenyiting/fts-hot-path-v19.test
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-collation-corpus.sql > results/v22-base-collation.txt 2> results/v22-base-collation.err
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-props-corpus.sql > results/v22-base-props.txt 2> results/v22-base-props.err
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-merge-corpus.sql > results/v22-base-merge.txt 2> results/v22-base-merge.err
python3 /home/chenyiting/fts-snapshot.py v22-base
stop_server
start_server v22
pids=()
for client in 1 2 3 4; do
 mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-v4-corpus.sql > results/v22-cold-$client.txt 2> results/v22-cold-$client.err &
 pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid"; done
for client in 1 2 3 4; do
 cmp results/v4-base-corpus.txt results/v22-cold-$client.txt
 cmp results/v4-base-corpus.err results/v22-cold-$client.err
done
echo PASS_V22_COLD_CONCURRENT
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v19.result < /home/chenyiting/fts-hot-path-v19.test
echo PASS_V22_REGRESSION
for spec in "props v22-base-props" "collation v22-base-collation" "merge v22-base-merge" "beng v8-base-beng" "v4 v4-base-corpus" "bmp v5-base-bmp"; do
 read -r corpus base <<< "$spec"
 mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-$corpus-corpus.sql > results/v22-$corpus.txt 2> results/v22-$corpus.err
 cmp results/$base.txt results/v22-$corpus.txt
 cmp results/$base.err results/v22-$corpus.err
 echo PASS_V22_$corpus
done
python3 /home/chenyiting/fts-snapshot.py v22-after
for q in cn beng mixed content; do cmp results/v22-base-$q.tsv results/v22-after-$q.tsv; done
echo PASS_V22_IDS_SCORES
for corpus in props v4 beng merge; do
 case "$corpus" in
 props) base=v22-base-props;; v4) base=v4-base-corpus;; beng) base=v8-base-beng;; merge) base=v22-base-merge;;
 esac
 pids=()
 for client in 1 2 3 4; do
  mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-$corpus-corpus.sql > results/v22-concurrent-$corpus-$client.txt 2> results/v22-concurrent-$corpus-$client.err &
  pids+=("$!")
 done
 for pid in "${pids[@]}"; do wait "$pid"; done
 for client in 1 2 3 4; do
  cmp results/$base.txt results/v22-concurrent-$corpus-$client.txt
  cmp results/$base.err results/v22-concurrent-$corpus-$client.err
 done
 echo PASS_V22_CONCURRENT_$corpus
done
for label in v21 v22 v22 v21; do
 stop_server
 start_server "$label"
 SKIP_LOAD=1 SAMPLES=5 QUERY_ROUNDS=600 LABEL="$label-full-abba" OUTPUT=$PWD/results/v22-$label-full-abba.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_V22_FULL_$label
done
stop_server
start_server v22
echo PASS_V22_COMPLETE
