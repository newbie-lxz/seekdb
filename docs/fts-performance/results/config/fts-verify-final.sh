#!/bin/bash
set -euo pipefail
cd /home/chenyiting/seekdb-fts-bench
source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh)
stop_server
start_server v18
LD_LIBRARY_PATH=/home/chenyiting/fts-test-client/extracted/usr/lib/x86_64-linux-gnu /home/chenyiting/fts-test-client/extracted/usr/bin/mysqltest --no-defaults --host=127.0.0.1 --port=2881 --user=root --database=oceanbase --result-file=results/fts_hot_path_v19.result < /home/chenyiting/fts-hot-path-v19.test
sha256sum bin/seekdb-before bin/seekdb-v10 bin/seekdb-v15 bin/seekdb-v16 bin/seekdb-v17 bin/seekdb-v18 bin/seekdb-v19 > results/final-binaries.sha256
sha256sum results/v18-base-* results/v18-after-* results/v18-props.* results/v18-collation.* results/v18-merge.* results/v18-beng.* results/v18-v4.* results/v18-bmp.* results/v18-concurrent-* results/fts_hot_path_v19.result > results/final-checks.sha256
cat /home/chenyiting/seekdb-fts-v2-build-time.txt
readlink /proc/$(cat server.pid)/exe
echo PASS_FINAL_V18_COMPLETE
