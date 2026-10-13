extends RefCounted
## Authored centre lines, full water widths and solid bed depths, in metres.
const RIVERS=[
 {"name":"Western Canyon River","width":18.0,"depth":4.5,"points":[Vector3(-553,27,-650),Vector3(-565,25,-480),Vector3(-542,23,-270),Vector3(-470,21,0),Vector3(-398,19,270),Vector3(-375,17,480),Vector3(-387,15,650)]},
 {"name":"Northern Gorge River","width":14.0,"depth":3.5,"points":[Vector3(120,52,-775),Vector3(350,49,-739),Vector3(600,46,-830),Vector3(850,43,-830),Vector3(1200,40,-831)]},
 {"name":"Expedition River","width":20.0,"depth":5.0,"points":[Vector3(180,56,1080),Vector3(420,53,1100),Vector3(750,49,1170),Vector3(1050,45,1210),Vector3(1414.213562,42,1270)]}
]
static var bins:Dictionary={}
const BIN:=128.0
static func prepare() -> void:
 if not bins.is_empty():return
 for river in RIVERS:
  for i in river.points.size()-1:
   var a:Vector3=river.points[i];var b:Vector3=river.points[i+1]
   var delta:=Vector2(b.x-a.x,b.z-a.z);var margin:float=river.width*.5+12
   var row:Dictionary={"a":a,"b":b,"delta":delta,"inv":1.0/delta.length_squared(),"width":river.width*.5,"depth":river.depth}
   for z in range(floori((minf(a.z,b.z)-margin)/BIN),floori((maxf(a.z,b.z)+margin)/BIN)+1):
    for x in range(floori((minf(a.x,b.x)-margin)/BIN),floori((maxf(a.x,b.x)+margin)/BIN)+1):
     var key:=Vector2i(x,z)
     if not bins.has(key):bins[key]=[]
     bins[key].append(row)
## mask, water level, depth. Dry points have mask zero.
static func sample(x:float,z:float) -> Vector3:
 prepare()
 var result:=Vector3.ZERO;var p:=Vector2(x,z)
 for row in bins.get(Vector2i(floori(x/BIN),floori(z/BIN)),[]):
  var t:=clampf((p-Vector2(row.a.x,row.a.z)).dot(row.delta)*row.inv,0,1)
  var distance:=p.distance_to(Vector2(row.a.x,row.a.z)+row.delta*t)
  var mask:=1-smoothstep(row.width,row.width+12,distance)
  if mask>result.x:result=Vector3(mask,lerpf(row.a.y,row.b.y,t),row.depth)
 return result
