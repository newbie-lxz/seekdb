#!/bin/bash
set -euo pipefail
cd /home/chenyiting
while kill -0 28745 2>/dev/null; do sleep 3; done
grep -q PASS_V11_COMPLETE fts-verify-v11.log
server_pid=$(cat seekdb-fts-bench/server.pid)
mysql -h127.0.0.1 -P2881 -uroot -e "SET ob_query_timeout=100000000000; ALTER TABLE fts_large_bench.docs DROP INDEX fti_all_ik;"
perf record -e cpu-clock:u -F 499 -p "$server_pid" -o fts-build-v11-profile.data -- mysql -h127.0.0.1 -P2881 -uroot -e "SET ob_query_timeout=100000000000; ALTER TABLE fts_large_bench.docs ADD FULLTEXT INDEX fti_all_ik(title,content) WITH PARSER ik;"
perf report --stdio --no-children --sort symbol --percent-limit 0.5 -i fts-build-v11-profile.data > fts-build-v11-profile.txt
chmod a+r fts-build-v11-profile.*
echo PASS_BUILD_PROFILE
