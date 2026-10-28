import random
from pathlib import Path
rng=random.Random(18472)
with Path('/home/chenyiting/fts-beng-corpus.sql').open('w') as f:
 f.write("SET NAMES utf8mb4; SET ob_query_timeout=100000000000;\n")
 inputs=[bytes(range(128)),b'I i A Z THE the',b'\x00\t\r\n Database. AUDIT!!',b' '*128,
         b'X' * 4095,b'X' * 4096,b'X' * 4097,b'database '*600]
 for i in range(220):
  inputs.append(bytes(rng.randrange(128) for _ in range(rng.randrange(1,600))))
 inputs.extend([(s+' Café CAFÉ 中文 😀').encode() for s in ['Database','I The AUDIT']])
 for value in inputs:
  for coll in ['utf8mb4_general_ci','utf8mb4_bin']:
   f.write("SELECT tokenize(CONVERT(UNHEX('"+value.hex()+"') USING utf8mb4) COLLATE "+coll+",'beng','[{\"output\":\"all\"}]');\n")
print('BENG queries',len(inputs)*2)
