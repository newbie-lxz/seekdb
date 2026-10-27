#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
stop_server() {
  pid=$(cat server.pid)
  if kill -0 "$pid" 2>/dev/null; then
    if [[ $(ps -p "$pid" -o args=) != *bin/seekdb-* ]]; then echo 'Unexpected server identity'; exit 1; fi
    kill -TERM "$pid"
  fi
  for ((i=0;i<180;i++)); do
    if ! ss -ltn | grep -q ':2881 '; then return; fi
    sleep 1
  done
  echo 'Server port did not close'; exit 1
}
start_server() {
  label=$1
  bin/seekdb-"$label" --nodaemon -P 2881 --parameter memory_limit=2G --parameter datafile_size=128M --parameter datafile_next=128M --parameter datafile_maxsize=2G --parameter log_disk_size=2G --parameter syslog_disk_size=256M > results/"$label"-repeat-server.log 2>&1 &
  echo $! > server.pid
  for ((i=0;i<240;i++)); do
    if mysql -h127.0.0.1 -P2881 -uroot -N -s -e 'SELECT 1' >/dev/null 2>&1; then return; fi
    if ! kill -0 "$(cat server.pid)" 2>/dev/null; then break; fi
    sleep 2
  done
  echo 'Server did not become ready'; exit 1
}

while kill -0 30607 2>/dev/null; do sleep 5; done
bash /home/chenyiting/seekdb-fts-v2-build.sh
echo PASS_V4_BUILD
cp /home/chenyiting/seekdb-src/build_release/src/observer/seekdb bin/seekdb-v4
stop_server
start_server v4
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v4.result < /home/chenyiting/fts-hot-path-v4.test
echo PASS_V4_REGRESSION
mysql --force -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < /home/chenyiting/fts-v4-corpus.sql > results/v4-after-corpus.txt 2> results/v4-after-corpus.err
cmp results/v4-base-corpus.txt results/v4-after-corpus.txt
cmp results/v4-base-corpus.err results/v4-after-corpus.err
echo PASS_V4_CORPUS_450
python3 /home/chenyiting/fts-snapshot.py v4-after-same-data
for q in cn beng mixed content; do cmp results/v4-base-same-data-$q.tsv results/v4-after-same-data-$q.tsv; done
echo PASS_V4_IDS_SCORES
LABEL=v4 OUTPUT=$PWD/results/v4-full.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
echo PASS_V4_FULL_BENCH
stop_server
start_server before
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v4.result < /home/chenyiting/fts-hot-path-v4.test
LABEL=v4-before OUTPUT=$PWD/results/v4-before-full.txt bash /home/chenyiting/seekdb-src/tools/benchmark/fts_large_bench.sh
echo PASS_V4_BEFORE_FULL_BENCH
stop_server
start_server v4
echo PASS_V4_COMPLETE
