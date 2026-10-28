from pathlib import Path
out=Path('/home/chenyiting/fts-bmp-corpus.sql')
chars=[i for i in range(65536) if not 0xd800<=i<=0xdfff]
with out.open('w') as f:
 f.write("SET NAMES utf8mb4; SET ob_query_timeout=100000000000;\n")
 for j in range(0,len(chars),32):
  value=''.join(chr(i) for i in chars[j:j+32]).encode().hex()
  for mode in ['smart','max_word']:
   f.write("SELECT tokenize(CONVERT(UNHEX('"+value+"') USING utf8mb4), 'ik', '[{\"output\":\"all\"},{\"additional_args\":[{\"ik_mode\":\""+mode+"\"}]}]');\n")
print('BMP queries',2*((len(chars)+31)//32))
