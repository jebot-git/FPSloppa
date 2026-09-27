"""Moderate silhouette pass; all sight, muzzle and interaction landmarks stay put.

Only authored vertex envelopes change. Actions retain their named mesh groups,
origins and pivots; contact knobs, magazines, apertures and bores are protected.
"""
def refine_profiles(objects,slot):
 report=[]
 receivers=['Sculpted frame','Faceted slide','Slide serrations','Ejection cutout','Chamber hood',
  'Shotgun receiver','Ejection port','Bolt face','Receiver pressed channel','HK polymer lower',
  'MP5 stamped receiver','AK milled lower','AK rounded dust cover','AK safety lever',
  'Receiver lightening recess','AR lower receiver','AR upper receiver','Ejection dust cover',
  'Brass deflector','M249 receiver','M249 feed cover','M249 ejection port',
  'Exposed feed tray','Feed tray channel','M4 flared magazine well','Recessed receiver pin',
  'Slide release','Magazine catch','Glock selector','Safety lever','HK selector','HK push pin',
  'USP accessory rail','USP rail lug']
 furniture=['M3 fixed stock','M3 recoil pad','XM adjustable cheekpiece','XM skeleton stock',
  'XM recoil pad','MP5 shoulder plate','MP5 stock end cap','AK wooden stock','AK steel buttplate',
  'CAR telescoping stock','CAR recoil pad','Stock adjustment lever','M249 fixed stock','M249 recoil pad']
 foreends=['Contoured fore-end','Pump ribs','XM fore-end rib','MP5 tapered wide fore-end',
  'AK lower wood handguard','AK upper wood handguard','Handguard retaining band',
  'M4 oval handguard','M4 fore-end rib','Delta ring','M249 ventilated fore-end','Fore-end cooling slots']
 for ob in objects:
  name=ob.name.split('.')[0];sx=1;sy=1;center=.085
  if name=='Reciprocating bolt handle':
   # Extend only the inner stem to the slimmer receiver; the gripped knob
   # and its authoritative contact point retain their original location.
   for vertex in ob.data.vertices:
    if vertex.co.x<.068:vertex.co.x-=.008
   ob.data.update()
  if name=='Forward assist':
   for vertex in ob.data.vertices:
    if vertex.co.x<.065:vertex.co.x-=.008
   ob.data.update()
  if name in receivers:sx=.88 if slot in [1,2,10] else .90
  if name in furniture:sx=.87
  if name in foreends:
   sx=.86;sy=.84
   if slot in [3,4]:center=.025;sy=.73 # expose barrel above a slimmer pump.
  if name=='P90 closed trigger guard and thumbhole chassis':sx=.90
  if name in ['P90 recoil pad','P90 stock inset','Chassis fastener']:sx=.90
  if name in ['AW thumbhole chassis','AW grip insert','AW cheek rest','AW stock spacer','AW recoil pad','AW stock fastener']:sx=.92
  if sx==1 and sy==1:continue
  for vertex in ob.data.vertices:
   vertex.co.x*=sx
   vertex.co.z=center+(vertex.co.z-center)*sy
  ob.data.update();report.append({'part':name,'width':sx,'height':sy})
 return report
