#!/bin/bash
set -euo pipefail
cd /home/chenyiting
while kill -0 38424 2>/dev/null; do sleep 3; done
grep -q PASS_V16_COMPLETE fts-verify-v16.log
server_pid=$(cat seekdb-fts-bench/server.pid)
for kind in limit; do
perf record -e cpu-clock:u -F 499 -p "$server_pid" -o fts-v16-$kind-profile.data -- mysql -h127.0.0.1 -P2881 -uroot -N -s --default-character-set=utf8mb4 < fts-v16-$kind-profile.sql > /dev/null
perf report -f --stdio --no-children --sort symbol --percent-limit 0.3 --column-widths 12,160 -i fts-v16-$kind-profile.data > fts-v16-$kind-profile.txt
done
chmod a+r fts-v16-*-profile.*
echo PASS_PROFILE_V16
