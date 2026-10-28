import json, random
from pathlib import Path
rng=random.Random(20481)
text="数据库 中华人民共和国 人民大会堂 全文索引 一百二十三个 OceanBase database audit ABC a an the 123.45 café"
valid=[
("ik", []),("beng", []),("space", []),("ngram", []),("ngram2", []),
("ik",[{"ik_mode":"smart"}]),("ik",[{"ik_mode":"max_word"}]),
("ik",[{"dict_table":"x"*1024}]),("ik",[{"dict_table":"y"*2048}])]
for parser in ["space","beng"]:
 for lo,hi in [(1,3),(2,8),(3,84),(5,12)]:
  valid.append((parser,[{"min_token_size":lo},{"max_token_size":hi}]))
for n in [1,2,3,4]:
 valid.append(("ngram",[{"ngram_token_size":n}]))
for lo,hi in [(1,2),(2,4),(3,5)]:
 valid.append(("ngram2",[{"min_ngram_size":lo},{"max_ngram_size":hi}]))
invalid=[("ik",[{"ik_mode":"bad"}]),("beng",[{"min_token_size":0}]),("beng",[{"min_token_size":20},{"max_token_size":3}]),("ngram",[{"ngram_token_size":0}]),("space",[{"unknown":1}])]
queries=[]
for i in range(260):
 parser,args=rng.choice(valid)
 cfg=[{"output":"all"}]
 if args: cfg.append({"additional_args":args})
 queries.append("SELECT tokenize(CONVERT(UNHEX('"+text.encode().hex()+"') USING utf8mb4),'"+parser+"','"+json.dumps(cfg,separators=(',',':'))+"');")
for parser,args in invalid*3:
 cfg=[{"output":"all"},{"additional_args":args}]
 queries.append("SELECT tokenize('database 数据库','"+parser+"','"+json.dumps(cfg,separators=(',',':'))+"');")
Path('/home/chenyiting/fts-props-corpus.sql').write_text("SET NAMES utf8mb4; SET ob_query_timeout=100000000000;\n"+"\n".join(queries)+"\n")
print('Property queries',len(queries))
