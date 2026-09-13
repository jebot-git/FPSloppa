extends RefCounted
const OUT="res://test-results/candidates1011/"
const Atlas=preload("res://deathmatch/maps/atmosphere.gd")
const Contents=preload("res://deathmatch/maps/contents.gd")
const SELECTED={"tf_vesper":["stn_gw02_gry1","med_dbrick6","metal_brnz_01"],"tf_pressureworks":["metal_iron1_07","ind_w02_blk1","med_cobstn1_2"]}
const PROBES={"tf_vesper":Vector3(15,2.2,24),"tf_pressureworks":Vector3(16.25,2.2,23.75)}
static func setup(tree: SceneTree,size: Vector2i) -> Array:
 tree.root.size=size;tree.root.content_scale_size=size;tree.root.msaa_3d=Viewport.MSAA_4X
 var world:=Node3D.new();tree.root.add_child(world)
 var state: SceneState=load("res://deathmatch/arena.tscn").get_state()
 for i in state.get_node_count():
  var name:=str(state.get_node_path(i)).get_file()
  if name not in ["Environment","DuskSun"]:continue
  var node: Node=WorldEnvironment.new() if name=="Environment" else DirectionalLight3D.new();node.name=name
  for j in state.get_node_property_count(i):node.set(state.get_node_property_name(i,j),state.get_node_property_value(i,j))
  world.add_child(node)
  if node is DirectionalLight3D:node.light_energy=.25;node.shadow_enabled=false
 var camera:=Camera3D.new();world.add_child(camera);camera.fov=70;camera.make_current()
 return [world,camera]
static func materials(level: Node) -> Array:
 var result: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if node.mesh:
   for i in node.mesh.get_surface_count():
    var mat: Material=node.get_active_material(i)
    if mat is ShaderMaterial and mat.get_shader_parameter("bake_texture") is Texture2D:result[mat]=true
 return result.keys()
static func still(level: Node,contrast: bool=true) -> void:
 for node in level.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
 for mat in materials(level):
  mat.set_shader_parameter("liquid_warp",false);mat.set_shader_parameter("map_uv_offset",Vector2.ZERO);mat.set_shader_parameter("contrast_lighting",contrast);mat.set_shader_parameter("surface_variation",true)
static func scene(map: String) -> Node:
 return ResourceLoader.load("res://maps/cache/"+map+"-lightmap1-bc7.scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
static func stats(values: Array) -> Dictionary:
 values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}
