import subprocess,time,json
from pathlib import Path
texts=["OceanBase是一款非常稳定的数据库，全文索引的分词器热路径优化包括解析器实例复用、停用词全局单例、内存池化数据结构等技术，在大量文档索引和查询场景下可以显著降低 CPU 开销。","The quick brown fox jumps over the lazy dog. Full-text search indexing requires efficient tokenization on the hot path."]
for label in ['v23','v24','v25','v25','v24','v23']:
 subprocess.run(['bash','-c',"source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh); stop_server; start_server "+label],check=True)
 for parser,text in zip(['ik','beng'],texts):
  for loops in [1000,100000,100000,100000]:
   sql=f"SET NAMES utf8mb4;SET ob_query_timeout=100000000000;SET @t='{text}';SELECT BENCHMARK({loops},TOKENIZE(@t,'{parser}'));"
   begin=time.perf_counter()
   p=subprocess.run(['mysql','-h127.0.0.1','-P2881','-uroot','-N','-s','--default-character-set=utf8mb4','-e',sql],capture_output=True)
   print(json.dumps(dict(label=label,parser=parser,loops=loops,seconds=time.perf_counter()-begin,returncode=p.returncode,output=p.stdout.decode(),error=p.stderr.decode())),flush=True)
