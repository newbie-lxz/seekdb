from pathlib import Path
import subprocess
import sys

label = sys.argv[1]
out = Path('/home/chenyiting/seekdb-fts-bench/results')
queries = {
    'cn': ("title, content", "全文索引 分词器"),
    'beng': ("title_en, content_en", "database performance audit"),
    'mixed': ("title, content", "OceanBase 稳定 database"),
    'content': ("content", "倒排索引 tokenizer"),
}
for name, (cols, text) in queries.items():
    match = f"MATCH({cols}) AGAINST('{text}')"
    sql = f"SET NAMES utf8mb4; SET ob_query_timeout=100000000000; SELECT id, ROUND({match},8) AS score FROM fts_large_bench.docs WHERE {match} ORDER BY id;"
    result = subprocess.run(['mysql', '-h127.0.0.1', '-P2881', '-uroot', '--batch', '--raw', '--default-character-set=utf8mb4', '-e', sql], check=True, capture_output=True)
    (out / f'{label}-{name}.tsv').write_bytes(result.stdout)
    print(name, len(result.stdout.splitlines()) - 1, flush=True)
