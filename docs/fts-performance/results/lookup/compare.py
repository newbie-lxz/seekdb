import re,json
from pathlib import Path
p=Path('/home/chenyiting/seekdb-fts-bench/results')
def parse(name):
 return {k:float(v) for k,v in re.findall(r'^([a-z0-9_]+):\s*(-?[0-9.]+)\s*$',(p/name).read_text(),re.M)}
before=parse('v5-before-full.txt')
runs=[parse('v5-full.txt'),parse('v5-repeat-full.txt')]
after={k:sum(r[k] for r in runs)/len(runs) for k in runs[0]}
groups={'build':['build_ik_all_sec','build_ik_content_sec','build_beng_en_sec'],'tokenize':['tokenize_ik_avg_ms','tokenize_beng_avg_ms'],'query':['query_cn_avg_ms','query_beng_avg_ms','query_mixed_avg_ms','query_limit_avg_ms']}
improvement={k:(before[k]-after[k])/before[k] for ks in groups.values() for k in ks}
group_improvement={g:sum(improvement[k] for k in ks)/len(ks) for g,ks in groups.items()}
result={'scope':'Local O1 VM comparison only; not a platform score or official baseline','baseline_run':'v5-before-full.txt','candidate_runs':['v5-full.txt','v5-repeat-full.txt'],'baseline':before,'candidate_mean':after,'improvement':improvement,'group_improvement':group_improvement,'mean_improvement':sum(group_improvement.values())/3,'rejected_arena_experiment':'v6-full.txt'}
(p/'v5-local-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'group_improvement':group_improvement,'mean_improvement':result['mean_improvement']},indent=2))
