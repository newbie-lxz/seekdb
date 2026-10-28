from pathlib import Path
import random
rng=random.Random(74391)
edges=['',' ','  ','a','a ','a  ','A','abc','abC','ABC ','é','e','É','ê','ß','ss','中文','中 文','数据库','全文索引','かな','カナ','한글','😀','𠀀','a\x00','a\x01','a\t','a\n','Ａ','ａ','１２３']
pairs=[(a.encode(),b.encode()) for a in edges for b in edges]
for i in range(600):
 a=''.join(chr(rng.choice(list(range(0x20,0xd800))+list(range(0xe000,0x10000)))) for j in range(rng.randrange(1,10)))
 b=a if i%3==0 else a+(' ' if i%3==1 else 'x')
 pairs.append((a.encode(),b.encode()))
for i in range(128):
 pairs.append((bytes([i]),bytes([(i+1)%128])))
for a in [b'\x80',b'\xc0\xaf',b'\xe0\x80\x80',b'\xed\xa0\x80',b'\xf4\x90\x80\x80',b'\xf5\x80\x80\x80',b'\xe4\xb8',b'\xf0\x9f\x98']:
 for b in [a,a+b' ',b'a',b'']:
  pairs.append((a,b))
sql=["SET NAMES utf8mb4; SET ob_query_timeout=100000000000;","DROP DATABASE IF EXISTS fts_collation_probe; CREATE DATABASE fts_collation_probe; USE fts_collation_probe;","CREATE TABLE pairs (id INT PRIMARY KEY, a VARBINARY(256), b VARBINARY(256));"]
for start in range(0,len(pairs),200):
 sql.append("INSERT INTO pairs VALUES "+",".join("("+str(i+1)+",UNHEX('"+a.hex()+"'),UNHEX('"+b.hex()+"'))" for i,(a,b) in enumerate(pairs[start:start+200],start))+";")
for coll in ['utf8mb4_general_ci','utf8mb4_bin']:
 lhs="CONVERT(a USING utf8mb4) COLLATE "+coll
 rhs="CONVERT(b USING utf8mb4) COLLATE "+coll
 sql.append("SELECT id, STRCMP("+lhs+","+rhs+"), ("+lhs+"="+rhs+"), ("+lhs+"<"+rhs+") FROM pairs ORDER BY id;")
 sql.append("SELECT id,HEX(a) FROM pairs ORDER BY "+lhs+",id;")
sql.append("SELECT id,STRCMP(a,b),(a=b),(a<b) FROM pairs ORDER BY id;")
sql.append("DROP DATABASE fts_collation_probe;")
Path('/home/chenyiting/fts-collation-corpus.sql').write_text('\n'.join(sql)+'\n')
print('Collation pairs',len(pairs))
