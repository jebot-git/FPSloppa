extends RefCounted
## Authoritative tuft contact, independent of renderer residency and foliage LOD.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const MAX_TILES:=128
const RADIUS:=1.1
static var tiles:Dictionary={}
static func tile(coord:Vector2i)->Dictionary:
 if tiles.has(coord):
  var cached:Dictionary=tiles[coord];tiles.erase(coord);tiles[coord]=cached;return cached
 if tiles.size()>=MAX_TILES:tiles.erase(tiles.keys()[0])
 var rng:=RandomNumberGenerator.new();rng.seed=8137+coord.x*73856093+coord.y*19349663
 var candidates:Dictionary={};var origin:=Vector2(coord)*Landscape.TILE-Vector2.ONE*Landscape.EXTENT*.5
 for z in 32:
  for x in 32:
   var fx:float=(x+.25+rng.randf()*.5)*2;var fz:float=(z+.25+rng.randf()*.5)*2
   rng.randf() # Rendered tuft angle uses this draw.
   if rng.randf()>.90:continue
   candidates[Vector2i(x,z)]=origin+Vector2(fx,fz)*Landscape.TILE/(Landscape.SAMPLES-1)
 var row:Dictionary={"candidates":candidates,"roots":{},"heights":{},"origin":origin};tiles[coord]=row;return row
static func height(row:Dictionary,cell:Vector2i)->float:
 if not row.heights.has(cell):
  var point:Vector2=row.origin+Vector2(cell)*Landscape.TILE/(Landscape.SAMPLES-1)
  # Rendering stores its source samples as float32 before interpolation.
  row.heights[cell]=PackedFloat32Array([Landscape.surface(point.x,point.y).x])[0]
 return row.heights[cell]
static func root(row:Dictionary,cell:Vector2i)->Vector3:
 if row.roots.has(cell):return row.roots[cell]
 var result:=Vector3.INF;var p:Vector2=row.candidates[cell]
 if Landscape.planting_allowed(p) and Landscape.rock_mask(p.x,p.y)<=.4:
  var local:Vector2=(p-row.origin)*(Landscape.SAMPLES-1)/Landscape.TILE
  var index:=Vector2i(floori(local.x),floori(local.y))
  var a:=height(row,index);var b:=height(row,index+Vector2i.RIGHT);var c:=height(row,index+Vector2i.DOWN);var d:=height(row,index+Vector2i.ONE)
  var h:=lerpf(lerpf(a,b,local.x-index.x),lerpf(c,d,local.x-index.x),local.y-index.y)
  if h>=1 and h<=330 and Vector2(b-a,c-a).length()/(Landscape.TILE/(Landscape.SAMPLES-1))<=.55:result=Vector3(p.x,h-.03,p.y)
 row.roots[cell]=result;return result
static func contains(point:Vector3)->bool:
 if not point.is_finite():return false
 var p:=Vector2(point.x,point.z);var half:=Vector2.ONE*Landscape.EXTENT*.5
 if absf(p.x)>half.x or absf(p.y)>half.y:return false
 var lo:Vector2i=Vector2i(((p+half-Vector2.ONE*RADIUS)/Landscape.TILE).floor())
 var hi:Vector2i=Vector2i(((p+half+Vector2.ONE*RADIUS)/Landscape.TILE).floor())
 for z in range(lo.y,hi.y+1):
  for x in range(lo.x,hi.x+1):
   var coord:=Vector2i(x,z)
   if x<0 or z<0 or x>=Landscape.GRID or z>=Landscape.GRID:continue
   var row:=tile(coord);var local:Vector2=(p-row.origin)*32/Landscape.TILE
   var lower:Vector2i=Vector2i((local-Vector2.ONE*RADIUS*32/Landscape.TILE).floor())
   var upper:Vector2i=Vector2i((local+Vector2.ONE*RADIUS*32/Landscape.TILE).floor())
   for iz in range(maxi(0,lower.y),mini(31,upper.y)+1):
    for ix in range(maxi(0,lower.x),mini(31,upper.x)+1):
     var cell:=Vector2i(ix,iz)
     if not row.candidates.has(cell):continue
     var candidate:Vector2=row.candidates[cell]
     if p.distance_squared_to(candidate)>=RADIUS*RADIUS:continue
     var tuft:=root(row,cell)
     if tuft.is_finite() and absf(point.y-tuft.y)<1.5:return true
 return false
