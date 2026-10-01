"""Assign motion to real assemblies and add recessed energy lenses at their bores."""
from mathutils import Vector,Matrix
from designs import lathe

def configure(meshes,key,anchors,mat):
 m=anchors[key]['muzzle'];z=m[1];tip=-m[2]-.015
 if key.startswith('tribes_'):
  slot=int(key.split('_')[1])
  for ob in meshes:
   name=ob.name
   if slot==0 and name.startswith('BlasterEmitter'):ob['motion']='slide';ob['amount']=[0,0,.018]
   elif slot==1 and name.startswith('VentedPlasmaHood'):
    ob['motion']='vent';ob['amount']=[0,.013,0]
   elif slot==4 and name=='GrenadeBreech':
    pivot=Vector((0,0,z));ob.data.transform(Matrix.Translation(ob.location-pivot));ob.location=pivot;ob['motion']='bolt';ob['amount']=[0,0,.036]
   elif slot==5 and name.startswith('HeatGuardRib'):ob['motion']='vent';ob['amount']=[0,.007,0]
   elif slot in [6,8] and name.startswith('FieldCoil'):ob['motion']='slide';ob['amount']=[0,0,.012];ob['lamp']=[.035,.28,.4] if slot==6 else [.05,.3,.09]
   elif slot==7 and name=='MortarCollar':
    pivot=Vector((0,0,z));ob.data.transform(Matrix.Translation(ob.location-pivot));ob.location=pivot;ob['motion']='bolt';ob['amount']=[0,0,.045]
  # Recessed lenses stay behind the firing plane. They emit light in the
  # material only; no extra runtime point lights or draw-loop allocations.
  if slot in [0,1,5,11]:
   color={0:[.035,.18,.35],1:[.3,.13,.025],5:[.04,.3,.12],11:[.35,.025,.018]}[slot]
   radius={0:.016,1:.040,5:.018,11:.022}[slot]
   centers=[(-.047*.72,z),(.047*.72,z)] if slot==0 else [(0,z)]
   for center in centers:
    ob=lathe('RecessedEnergyLens',[(tip-.018,radius),(tip-.014,radius),(tip-.014,.0008),(tip-.018,.0008)],center,mat('Emitter ceramic',tuple(color),.05),20);ob['lamp']=color;meshes.append(ob)
 elif key=='ut99_1':
  for ob in meshes:
   if ob.name=='InjectorNozzle':ob['motion']='slide';ob['amount']=[0,0,.016]
 elif key=='ut99_7':
  for ob in meshes:
   if ob.name.startswith(('PulseEmitter','EmitterInsulator')):
    pivot=Vector((0,0,z));ob.data.transform(Matrix.Translation(-pivot));ob.location+=pivot;ob['motion']='spin';ob['amount']=[0,0,1]
 elif key=='doom_2':
  for ob in meshes:
   if ob.name=='Hammer':
    pivot=sum((v.co for v in ob.data.vertices),Vector())/len(ob.data.vertices);ob.data.transform(Matrix.Translation(-pivot));ob.location+=pivot
