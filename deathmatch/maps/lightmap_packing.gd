extends RefCounted
## Import-time atlas compaction; copies existing light samples and gutters.
static func pack(level: Node,layout: Array) -> Dictionary:
 var rects: Array=layout.duplicate(true)
 var mats: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D:mats[mat]=true
 if mats.is_empty():return {}
 var old: Image=mats.keys()[0].get_shader_parameter("bake_texture").get_image()
 rects.sort_custom(func(a,b):return a.rect.size.y>b.rect.size.y if a.rect.size.y!=b.rect.size.y else a.rect.size.x>b.rect.size.x)
 var size:=256;var area:=0
 for row in rects:area+=row.rect.size.x*row.rect.size.y
 while true:
  var cursor:=Vector2i(2,0);var shelf:=0;var fits:=true
  for row in rects:
   var r: Rect2i=row.rect
   if r.size.x+2>size or r.size.y>size:fits=false;break
   if cursor.x+r.size.x>size:cursor=Vector2i(0,cursor.y+shelf);shelf=0
   if cursor.y+r.size.y>size:fits=false;break
   row.target=cursor;cursor.x+=r.size.x;shelf=maxi(shelf,r.size.y)
  if fits:break
  size*=2
  assert(size<=8192)
 var image:=Image.create(size,size,false,old.get_format());image.fill(Color(.5,.5,.5))
 var lookup:=PackedInt32Array();lookup.resize(old.get_width()*old.get_height());lookup.fill(-1)
 for i in rects.size():
  var r: Rect2i=rects[i].rect;image.blit_rect(old,r,rects[i].target)
  for y in range(r.position.y,r.end.y):
   for x in range(r.position.x,r.end.x):lookup[y*old.get_width()+x]=i
 var texture:=ImageTexture.create_from_image(image)
 for mat in mats:mat.set_shader_parameter("bake_texture",texture)
 var count:=0
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh is ArrayMesh:continue
  var mesh: ArrayMesh=node.mesh;var result:=ArrayMesh.new()
  for surface in mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_TEX_UV2]!=null:
    var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
    for i in uvs.size():
     var pixel:=uvs[i]*old.get_width();var point:=Vector2i(pixel.floor())
     var id: int=lookup[point.y*old.get_width()+point.x] if point.x>=0 and point.y>=0 and point.x<old.get_width() and point.y<old.get_height() else -1
     if id>=0:uvs[i]=(pixel-Vector2(rects[id].rect.position)+Vector2(rects[id].target))/size
     else:uvs[i]=Vector2(.5,.5)/size
     count+=1
    arrays[Mesh.ARRAY_TEX_UV2]=uvs
   result.add_surface_from_arrays(mesh.surface_get_primitive_type(surface),arrays)
   result.surface_set_material(surface,mesh.surface_get_material(surface))
   result.surface_set_name(surface,mesh.surface_get_name(surface))
  node.mesh=result

 return {"from":[old.get_width(),old.get_height()],"to":[size,size],"patches":rects.size(),"padded_luxels":area,"occupancy_before":float(area)/(old.get_width()*old.get_height()),"occupancy_after":float(area)/(size*size),"raw_bytes_before":old.get_data_size(),"raw_bytes_after":image.get_data_size(),"remapped_vertices":count}
