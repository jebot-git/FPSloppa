"""Convert the four accepted simple-mechanics Assault maps."""
from build_koth import *
ORDER={'AS-Pumpfac':['FortStandard0','FortStandard2','FortStandard1'],'AS-Skyville':['FortStandard1','FortStandard2','FortStandard0'],'AS-Twintower':['FortStandard0','FortStandard1'],'AS-Atlantica':['FortStandard0','FortStandard1','FortStandard2']}
if __name__=='__main__':
 candidates={r['name']:r for r in json.loads((HERE/'as-candidates.json').read_text())['candidates'][:4]};results=[]
 for row in json.loads((HERE/'downloads.json').read_text()):
  if row['name'] not in ORDER or len(sys.argv)>1 and row['name'].lower().removeprefix('as-') not in sys.argv[1:]:continue
  candidate=candidates[row['name']]
  if row['archive_sha1']!=candidate['archive_sha1']:continue
  plan={'id':'as_ut_'+row['name'][3:].lower(),'objectives':[next(o for o in candidate['objectives'] if o['actor']==name) for name in ORDER[row['name']]]}
  try:results.append(build(row,plan))
  except Exception as e:print(row['name'],'FAILED',e,flush=True);results.append(dict(source=row,status='failed',error=str(e)))
 (HERE/'as-builds.json').write_text(json.dumps(results,indent=2)+'\n')
 raise SystemExit(any(r['status']=='failed' for r in results))
