import subprocess,time,json
queries=["database","database missingtoken","database audit","database performance audit","missingtoken othermissing"]
for label in ['v21','v23','v23','v21']:
 subprocess.run(['bash','-c',"source <(sed '/^start_server v4/,$d' /home/chenyiting/fts-start-v4.sh); stop_server; start_server "+label],check=True)
 for q in queries:
  sql="SET NAMES utf8mb4;SET ob_query_timeout=100000000000;"+(f"SELECT COUNT(*) FROM (SELECT id FROM fts_large_bench.docs WHERE MATCH(title_en,content_en) AGAINST('{q}') LIMIT 20) t;"*500)
  begin=time.perf_counter()
  p=subprocess.run(['mysql','-h127.0.0.1','-P2881','-uroot','-N','-s','--default-character-set=utf8mb4'],input=sql.encode(),stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
  print(json.dumps(dict(label=label,q=q,seconds=time.perf_counter()-begin,returncode=p.returncode,error=p.stderr.decode())),flush=True)
