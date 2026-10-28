#!/bin/bash
set -euo pipefail
while kill -0 47611 2>/dev/null; do sleep 3; done
grep -q "^PASS_BUILD_V19$" /home/chenyiting/fts-v19-build-driver.log
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v19
stop_server
start_server before
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --record --result-file=results/fts_hot_path_v19.result < /home/chenyiting/fts-hot-path-v19.test
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-collation-corpus.sql > results/v19-base-collation.txt 2> results/v19-base-collation.err
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-props-corpus.sql > results/v19-base-props.txt 2> results/v19-base-props.err
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-merge-corpus.sql > results/v19-base-merge.txt 2> results/v19-base-merge.err
python3 /home/chenyiting/fts-snapshot.py v19-base
stop_server
start_server v19
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v19.result < /home/chenyiting/fts-hot-path-v19.test
echo PASS_V19_REGRESSION
for spec in "props v19-base-props" "collation v19-base-collation" "merge v19-base-merge" "beng v8-base-beng" "v4 v4-base-corpus" "bmp v5-base-bmp"; do
 read -r corpus base <<< "$spec"
 mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-$corpus-corpus.sql > results/v19-$corpus.txt 2> results/v19-$corpus.err
 cmp results/$base.txt results/v19-$corpus.txt
 cmp results/$base.err results/v19-$corpus.err
 echo PASS_V19_$corpus
done
python3 /home/chenyiting/fts-snapshot.py v19-after
for q in cn beng mixed content; do cmp results/v19-base-$q.tsv results/v19-after-$q.tsv; done
echo PASS_V19_IDS_SCORES
for corpus in props v4 beng merge; do
 case "$corpus" in
 props) base=v19-base-props;; v4) base=v4-base-corpus;; beng) base=v8-base-beng;; merge) base=v19-base-merge;;
 esac
 pids=()
 for client in 1 2 3 4; do
  mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-$corpus-corpus.sql > results/v19-concurrent-$corpus-$client.txt 2> results/v19-concurrent-$corpus-$client.err &
  pids+=("$!")
 done
 for pid in "${pids[@]}"; do wait "$pid"; done
 for client in 1 2 3 4; do
  cmp results/$base.txt results/v19-concurrent-$corpus-$client.txt
  cmp results/$base.err results/v19-concurrent-$corpus-$client.err
 done
 echo PASS_V19_CONCURRENT_$corpus
done
for label in before v19 v19 before; do
 stop_server
 start_server "$label"
 LABEL="$label-full-abba" OUTPUT=$PWD/results/v19-$label-full-abba.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
 echo PASS_V19_FULL_$label
done
stop_server
start_server v19
echo PASS_V19_COMPLETE
