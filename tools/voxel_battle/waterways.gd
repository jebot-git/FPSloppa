extends Node3D
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var bridges:Array=[]
var triangles:=0
func build(map,graphics:bool,physics:bool) -> void:
 Landscape.prepare_roads()
 # Preserve the roadway above a carved bed with separate solid bridge decks.
 var deck:=SurfaceTool.new();deck.begin(Mesh.PRIMITIVE_TRIANGLES)
 for road in Landscape.main_roads:
  var wet:=false
  for i in maxi(2,ceili(road.delta.length()/3))+1:
   var p:Vector3=road.a.lerp(road.b,float(i)/maxi(2,ceili(road.delta.length()/3)))
   if Landscape.water_mask(p.x,p.z)>.001:wet=true;break
  if not wet:continue
  var delta:Vector3=road.b-road.a
  var length:=delta.length()+.4
  var frame:=Transform3D(Basis.looking_at(-delta.normalized(),Vector3.UP),(road.a+road.b)*.5-Vector3.UP*.18)
  var size:=Vector3(road.width*2+.6,.36,length)
  bridges.append({"frame":frame,"size":size})
  if physics:
   var body:=StaticBody3D.new();body.transform=frame;add_child(body)
   var shape:=BoxShape3D.new();shape.size=size
   var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
  if graphics:
   var box:=BoxMesh.new();box.size=size
   deck.append_from(box,0,frame)
 if not graphics:return
 if not bridges.is_empty():
  var mesh:=MeshInstance3D.new();mesh.name="RiverRoadBridges";mesh.mesh=deck.commit()
  var material:=StandardMaterial3D.new();material.albedo_color=Color(.32,.33,.30);material.roughness=.95;mesh.material_override=material;add_child(mesh)
 # One surface per spatial tile permits ordinary frustum culling of waterways.
 var tiles:Dictionary=Landscape.Hydrology.bins.duplicate()
 for z in range(6,12):
  for x in range(-8,-3):tiles[Vector2i(x,z)]=[]
 for coord in tiles:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var count:=0
  for iz in 16:
   for ix in 16:
    var a:=Vector2(coord.x*128+ix*8,coord.y*128+iz*8)
    if absf(a.x)>Landscape.EXTENT/2 or absf(a.y)>Landscape.EXTENT/2:continue
    for face in [[a,a+Vector2(8,0),a+Vector2(0,8)],[a+Vector2(8,0),a+Vector2(8,8),a+Vector2(0,8)]]:
     var polygon:Array=[]
     for i in 3:
      var p:Vector2=face[i];var q:Vector2=face[(i+1)%3]
      var pm:float=Landscape.water_mask(p.x,p.y);var qm:float=Landscape.water_mask(q.x,q.y)
      if pm>=.5:polygon.append(p)
      if (pm>=.5)!=(qm>=.5):polygon.append(p.lerp(q,(.5-pm)/(qm-pm)))
     for j in range(1,polygon.size()-1):
      for p in [polygon[0],polygon[j],polygon[j+1]]:
       var sample:Vector3=Landscape.water_sample(p.x,p.y)
       st.set_normal(Vector3.UP);st.add_vertex(Vector3(p.x,sample.y+.015,p.y))
      count+=1
  if count==0:continue
  var mesh:=MeshInstance3D.new();mesh.name="Water_%s"%str(coord);mesh.mesh=st.commit()
  mesh.material_override=material();mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh);triangles+=count
static var water_material:ShaderMaterial
static func material() -> ShaderMaterial:
 if water_material==null:
  water_material=ShaderMaterial.new();water_material.shader=preload("res://tools/voxel_battle/water.gdshader")
 return water_material
func navigation_source(data:NavigationMeshSourceGeometryData3D,bounds:AABB) -> void:
 for row in bridges:
  if bounds.intersects(row.frame*AABB(-row.size*.5,row.size)):
   var box:=BoxMesh.new();box.size=row.size
   data.add_mesh_array(box.get_mesh_arrays(),row.frame)
