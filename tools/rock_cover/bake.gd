extends SceneTree
## Offline only: OBJ payload -> shared indexed mesh LODs, convex cover and deterministic layout.
const ROOT="res://experimental-assets/jungle/rocks/"
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
var assets:Array=[]
var rows:Array=[]
var formations:Array=[]
var rng:=RandomNumberGenerator.new()
var tree_tiles:Dictionary={}
func _initialize()->void:run.call_deferred()
func vector(v:Array)->Vector3:return Vector3(v[0],v[1],v[2])
func packed(values:Array)->PackedVector3Array:
 var result:=PackedVector3Array()
 for v in values:result.append(vector(v))
 return result
func clear_at(p:Vector2,radius:float,river:bool=false)->bool:
 if maxf(absf(p.x),absf(p.y))+radius>Landscape.EXTENT*.5-25:return false
 for i in Landscape.CENTERS.size():
  var center:Vector3=Landscape.CENTERS[i]
  if maxf(absf(p.x-center.x),absf(p.y-center.z))<Landscape.RADII[i]+radius+22:return false
 for bins in [Landscape.road_bins,Landscape.access_bins]:
  # Query neighbouring bins as a large boulder can overlap a road in the next bin.
  for offset in [Vector2.ZERO,Vector2(radius+8,0),Vector2(-radius-8,0),Vector2(0,radius+8),Vector2(0,-radius-8)]:
   var near:=Landscape.nearest_road(p+offset,bins)
   if not near.is_empty():
    var road:Dictionary=near.road
    var a:=Vector2(road.a.x,road.a.z);var b:=Vector2(road.b.x,road.b.z)
    var t:=clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
    if p.distance_to(a.lerp(b,t))<road.width+radius+7:return false
 if not river and Landscape.water_mask(p.x,p.y)>.01:return false
 for row in rows:
  var q:=Vector2(row.position[0],row.position[2])
  if p.distance_to(q)<radius+float(row.radius)+1.2:return false
 # Avoid trunk intersections; visual shrubs around a rock base remain natural.
 var lo:=Landscape.bin_key(p-Vector2.ONE*(radius+3));var hi:=Landscape.bin_key(p+Vector2.ONE*(radius+3))
 for z in range(lo.y,hi.y+1):
  for x in range(lo.x,hi.x+1):
   var key:=Vector2i(x,z)
   if not tree_tiles.has(key):tree_tiles[key]=Landscape.features(key)
   for tree in tree_tiles[key]:
    if tree.kind==2:continue
    if p.distance_to(Vector2(tree.position.x,tree.position.z))<radius+float(tree.scale)*.5:return false
 return true
func add_rock(p:Vector2,kind:int,height:float,tag:String,formation:int)->bool:
 var spec:Dictionary=assets[kind];var size:=vector(spec.size);var scale_value:=height/size.y
 var radius:=Vector2(size.x,size.z).length()*.5*scale_value
 var river:=tag=="river"
 if not clear_at(p,radius,river):return false
 var ground:=Landscape.surface(p.x,p.y).x
 var low:=ground;var high:=ground
 for offset in [Vector2(radius*.65,0),Vector2(-radius*.65,0),Vector2(0,radius*.65),Vector2(0,-radius*.65)]:
  var h:=Landscape.surface(p.x+offset.x,p.y+offset.y).x;low=minf(low,h);high=maxf(high,h)
 if high-low>height*.65:return false
 # Embed the skirt into uneven terrain; tall river rocks sit on the solid bed.
 var y:=low-height*.10
 if river:
  var water:=Landscape.water_sample(p.x,p.y)
  if water.x<.95 or y+height<water.y+.5:return false
 rows.append({"asset":kind,"position":[p.x,y,p.y],"angle":rng.randf()*TAU,"scale":scale_value,"radius":radius,"height":height,"tag":tag,"formation":formation})
 return true
func cluster(p:Vector2,tag:String)->void:
 var id:=formations.size();var start:=rows.size()
 var height:=rng.randf_range(2.4,4.8) if tag=="outcrop" else rng.randf_range(1.25,2.3)
 var kind:=rng.randi_range(0,9)
 if not add_rock(p,kind,height,tag,id):return
 for j in rng.randi_range(1,3):
  var angle:=rng.randf()*TAU;var distance:=float(rows[start].radius)+rng.randf_range(1.5,4)
  var point:=p+Vector2(cos(angle),sin(angle))*distance
  add_rock(point,rng.randi_range(0,9),rng.randf_range(.7,1.5),tag,id)
 # A few tiny loose stones tie the large formation into its ground, no collision.
 if rng.randf()<.45:
  var point:=p+Vector2(rng.randf_range(-6,6),rng.randf_range(-6,6))
  add_rock(point,rng.randi_range(10,13),rng.randf_range(.12,.24),"loose",id)
 formations.append({"tag":tag,"first":start,"count":rows.size()-start})
func layout()->void:
 Landscape.prepare_roads();rng.seed=0x524f434b
 # Satellite outcrops belong to the six existing rocky terrain ridges.
 for rock in Landscape.ROCK_FORMATIONS:
  for attempt in 30:
   var a:=rng.randf()*TAU;var r:float=rng.randf_range(.65,1.65)*rock.z
   cluster(Vector2(rock.x,rock.y)+Vector2(cos(a),sin(a))*r,"outcrop")
   if formations.size()>=(Landscape.ROCK_FORMATIONS.find(rock)+1)*7:break
 # Broken exposed shoulders / foothills across otherwise unoccupied wilderness.
 var target:=formations.size()+28
 for attempt in 1200:
  var p:=Vector2(rng.randf_range(-1300,1300),rng.randf_range(-1300,1300))
  var h:=Landscape.surface(p.x,p.y).x
  var slope:=Vector2(Landscape.surface(p.x+3,p.y).x-Landscape.surface(p.x-3,p.y).x,Landscape.surface(p.x,p.y+3).x-Landscape.surface(p.x,p.y-3).x).length()/6
  if h>14 and slope>.08 and slope<.55:cluster(p,"foothill")
  if formations.size()>=target:break
 # Sparse roadside cover on the outside of the cleared verge.
 target=formations.size()+28
 for attempt in 500:
  var road:Dictionary=Landscape.main_roads[rng.randi_range(0,Landscape.main_roads.size()-1)]
  var p:Vector3=road.a.lerp(road.b,rng.randf_range(.12,.88));var tangent:=Vector2(road.b.x-road.a.x,road.b.z-road.a.z).normalized()
  var offset:Vector2=Vector2(-tangent.y,tangent.x)*(road.width+rng.randf_range(13,25))*(1 if rng.randf()>.5 else -1)
  cluster(Vector2(p.x,p.z)+offset,"verge")
  if formations.size()>=target:break
 # Riverbanks, plus occasional narrow exposed rocks rooted in the channel bed.
 for river in Landscape.Hydrology.RIVERS:
  for i in range(river.points.size()-1):
   var a:Vector3=river.points[i];var b:Vector3=river.points[i+1];var tangent:=Vector2(b.x-a.x,b.z-a.z).normalized();var side:=Vector2(-tangent.y,tangent.x)
   for sign_value in [-1,1]:
    var p:Vector3=a.lerp(b,rng.randf_range(.25,.75));cluster(Vector2(p.x,p.z)+side*sign_value*(river.width*.5+15),"bank")
   if i%2==0:
    var p:Vector3=a.lerp(b,.56);var point:Vector2=Vector2(p.x,p.z)+side*river.width*.28
    var ground:=Landscape.surface(point.x,point.y).x;var water:=Landscape.water_sample(point.x,point.y)
    var id:=formations.size()
    if add_rock(point,6,water.y-ground+1.4,"river",id):formations.append({"tag":"river","first":rows.size()-1,"count":1})
func run()->void:
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"));assets=source.assets
 var material:=StandardMaterial3D.new();material.albedo_texture=load(ROOT+"albedo.png");material.roughness=1
 var baked:=Lighting.surface(material);assert(ResourceSaver.save(baked,ROOT+"rock.material")==OK);baked.take_over_path(ROOT+"rock.material")
 var specs:Array=[]
 for asset in assets:
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=packed(asset.vertices);arrays[Mesh.ARRAY_NORMAL]=packed(asset.normals)
  var uv:=PackedVector2Array()
  for p in asset.uv:uv.append(Vector2(p[0],p[1]))
  arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(asset.indices)
  var importer:=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},baked);importer.generate_lods(60,60,[])
  var mesh:=importer.get_mesh();var path:String=ROOT+asset.id+".res";assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
  var collision_path:=""
  if not asset.collision.is_empty():
   var shape:=ConvexPolygonShape3D.new();shape.points=packed(asset.collision);collision_path=ROOT+asset.id+"-collision.res";assert(ResourceSaver.save(shape,collision_path,ResourceSaver.FLAG_COMPRESS)==OK)
  var lods:Array=[asset.indices.size()/3]
  for i in importer.get_surface_lod_count(0):lods.append(importer.get_surface_lod_indices(0,i).size()/3)
  specs.append({"id":asset.id,"mesh":path,"collision":collision_path,"size":asset.size,"lod_triangles":lods,"nav_faces":asset.get("collision_faces",[])})
 layout()
 var sources:Dictionary={}
 for file in ["res://tools/rock_cover/bake.gd","res://tools/voxel_battle/landscape.gd","res://tools/voxel_battle/hydrology.gd",ROOT+"source.json"]:sources[file]=FileAccess.get_sha256(file)
 var result:={"version":1,"assets":specs,"formations":formations,"rows":rows,"sources":sources,"seed":0x524f434b}
 FileAccess.open(ROOT+"layout.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("ROCK_COVER_BAKED ",JSON.stringify({"assets":assets.size(),"formations":formations.size(),"rocks":rows.size(),"river":rows.filter(func(row):return row.tag=="river").size(),"lods":specs.map(func(row):return row.lod_triangles)}));quit()
