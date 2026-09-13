extends RefCounted
## Offline/source-import artwork refinement; keep separate coloured emission.
const Mips=preload("res://deathmatch/maps/colour_mips.gd")
static func apply(level: Node,map: String) -> void:
 var seen: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var mat: Material=node.get_active_material(i)
   if not mat is ShaderMaterial or seen.has(mat):continue
   seen[mat]=true
   var name: String=mat.get_meta("bsp_texture_name","")
   if name!="tlight12" and name!="*lava1" and not (map=="tf_vesper" and name.begins_with("stn_gr01_")):continue
   var base: Texture2D=mat.get_shader_parameter("base_texture")
   var source: Texture2D=mat.get_shader_parameter("glow_texture")
   if not base or (name in ["tlight12","*lava1"] and not source):continue
   var image:=base.get_image();var old: Image=source.get_image() if source else null
   if image.is_compressed() or (old and old.is_compressed()):continue
   var result:=Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGB8)
   for y in image.get_height():
    for x in image.get_width():
     var value:=Color.BLACK
     if name=="tlight12":
      var centre:=1.0-absf((x+.5)/image.get_width()*2.0-1.0)
      value=old.get_pixel(x,y)*Color(1.0,.75+.17*centre,.48+.30*centre)*(.8+.2*centre)
     elif name=="*lava1":
      var colour:=old.get_pixel(x,y)
      var core:=smoothstep(.42,.9,colour.r)*smoothstep(.08,.7,colour.g)
      value=colour*(.72+.28*core)
     else:
      var uv:=Vector2((x+.5)/image.get_width(),(y+.5)/image.get_height())-Vector2(.5,.5)
      var radius:=uv.length();var theta:=atan2(uv.y,uv.x)
      var ring:=smoothstep(.09,.14,radius)*(1.0-smoothstep(.33,.39,radius))
      value=image.get_pixel(x,y)*(ring*smoothstep(.2,.7,cos(theta*12.0))*.65)
     result.set_pixel(x,y,value)
   var texture:=ImageTexture.create_from_image(Mips.build(result));texture.set_meta(Mips.TAG,Mips.VERSION*2)
   for key in ["glow_texture","glow_nearest","glow_linear"]:mat.set_shader_parameter(key,texture)
   mat.set_shader_parameter("has_glow",true)
