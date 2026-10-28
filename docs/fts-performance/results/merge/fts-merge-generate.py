from pathlib import Path
out=Path('/home/chenyiting/fts-merge-corpus.sql')
queries=[
 ('title_en,content_en','database'),('title_en,content_en','missingtoken'),
 ('title_en,content_en','database audit'),('title_en,content_en','audit database'),
 ('title_en,content_en','database missingtoken'),('title_en,content_en','database performance audit'),
 ('title_en,content_en','audit performance database'),('title_en,content_en','database performance missingtoken'),
 ('title_en,content_en','database performance audit security'),
 ('title_en,content_en','database performance audit missingtoken'),
 ('title,content','全文索引'),('title,content','全文索引 分词器'),
 ('title,content','OceanBase 稳定 database'),('title,content','倒排索引 tokenizer'),
 ('content','倒排索引 tokenizer'),('content','稳定 性能 优化'),
]
with out.open('w') as f:
 f.write("SET NAMES utf8mb4; SET ob_query_timeout=100000000000;\n")
 for cols,txt in queries:
  m="MATCH("+cols+") AGAINST('"+txt+"')"
  f.write("SELECT id, ROUND("+m+",12) FROM fts_large_bench.docs WHERE "+m+" ORDER BY id;\n")
  f.write("SELECT id, ROUND("+m+",12) FROM fts_large_bench.docs WHERE "+m+" ORDER BY "+m+" DESC,id LIMIT 67 OFFSET 11;\n")
 for txt in ['+database -audit','database audit','+database +performance','database performance -audit','+database missingtoken']:
  m="MATCH(title_en,content_en) AGAINST('"+txt+"' IN BOOLEAN MODE)"
  f.write("SELECT id, ROUND("+m+",12) FROM fts_large_bench.docs WHERE "+m+" ORDER BY id;\n")
print('merge queries',2*len(queries)+5)
