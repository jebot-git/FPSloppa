extends RefCounted
## Local spectator director. Never changes world collision or server state.
var position:=Vector3.ZERO
var focus:=Vector3.ZERO
var radius:=20.
var ready:=false
var materials: Array[ShaderMaterial]=[]
var bound_map: Node
var maximum_step:=0.
var frames:=0
var clearance_corrections:=0
var clearance_failures:=0
var sphere:=SphereShape3D.new()
var safe_position:=Vector3.ZERO
var has_safe_position:=false
const HEADING=Vector3(.5,.70710678,.5)
const CUTAWAY="""
uniform vec3 overview_eye;
uniform vec3 overview_subjects[5];
uniform int overview_count = 0;
"""
const DISCARD="""
    vec3 overview_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    for (int overview_i = 0; overview_i < 5; overview_i++) {
        if (overview_i >= overview_count) break;
        vec3 subject = overview_subjects[overview_i];
        vec3 sight = subject + vec3(0.0, 1.0, 0.0) - overview_eye;
        float along = dot(overview_world - overview_eye, sight) / max(dot(sight, sight), 0.001);
        vec3 axis = overview_eye + sight * clamp(along, 0.0, 1.0);
        // Keep the supporting floor. Cut only foreground geometry in the team's viewing corridors.
        if (along > 0.0 && along < 1.03 && overview_world.y > subject.y + 0.20 && distance(overview_world, axis) < 4.5)
            discard;
    }
"""
func bind(level: Node):
 if bound_map==level:return
 bound_map=level;materials.clear()
 var shaders: Dictionary={}
 for node in level.find_children("*","MeshInstance3D",true,false):
  if not node.mesh:continue
  for i in node.mesh.get_surface_count():
   var original=node.get_active_material(i)
   if not original is ShaderMaterial:continue
   var code: String=original.shader.code
   if not "void fragment() {" in code or not "bake_texture" in code:continue
   if not shaders.has(original.shader):
    var shader:=Shader.new()
    shader.code=code.replace("void fragment() {",CUTAWAY+"\nvoid fragment() {"+DISCARD)
    shaders[original.shader]=shader
   var material: ShaderMaterial=original.duplicate()
   material.shader=shaders[original.shader]
   node.set_surface_override_material(i,material);materials.append(material)
func update(game,delta: float):
 var points: Array[Vector3]=[]
 var fallback: Array[Vector3]=[]
 for id in game.players:
  var state: Dictionary=game.players[id]
  if id>=0 or state.dead or state.spectator or not game.fighters.has(id):continue
  var p: Vector3=game.fighters[id].render_position()
  fallback.append(p)
  if state.team==0:points.append(p)
 if points.is_empty():points=fallback
 if points.is_empty():return
 if points.size()>5:points.resize(5)
 bind(game.get_node("Map"))
 var lo: Vector3=points[0];var hi: Vector3=points[0]
 for p in points:lo=lo.min(p);hi=hi.max(p)
 var target: Vector3=(lo+hi)*.5+Vector3.UP
 var desired_radius:=15.
 for p in points:desired_radius=maxf(desired_radius,p.distance_to(target)*1.85+6)
 desired_radius=clampf(desired_radius,15,80)
 var dt:=clampf(delta,0.,.1)
 if not ready:
  focus=target;radius=desired_radius;position=focus+HEADING*radius;ready=true
 else:
  # Persistent state: the game's ordinary spectator update overwrites Camera3D each frame.
  # Reading that camera transform here would reintroduce jitter even with lerp().
  focus=focus.move_toward(focus.lerp(target,1-exp(-1.8*dt)),12*dt)
  radius=move_toward(radius,lerpf(radius,desired_radius,1-exp(-1.2*dt)),8*dt)
  var next: Vector3=position.move_toward(position.lerp(focus+HEADING*radius,1-exp(-2.5*dt)),16*dt)
  maximum_step=maxf(maximum_step,position.distance_to(next));position=next
 position=clear_position(game,position)
 game.camera.get_viewport().use_occlusion_culling=false
 game.camera.near=.08
 game.camera.global_position=position
 game.camera.look_at(focus)
 game.camera.fov=65
 for material in materials:
  material.set_shader_parameter("overview_eye",position)
  material.set_shader_parameter("overview_count",points.size())
  var subjects:=PackedVector3Array(points)
  subjects.resize(5)
  material.set_shader_parameter("overview_subjects",subjects)
 frames+=1

func solid_at(game,p: Vector3) -> bool:
 var runtime=game.get_node_or_null("Map/MapRuntime")
 if runtime==null or not runtime.ballistics.ready:return false
 var pen=runtime.ballistics
 if pen.bsp_cover:
  var bsp=pen.bsp_cover
  for model in bsp.models:
   if model.id!=0 and model.node.collision_layer&1==0:continue
   var local: Vector3=p-model.node.global_position
   var index: int=model.head
   var steps:=0
   while index>=0 and steps<4096:
    var row: Array=bsp.nodes[index]
    index=row[1] if bsp.planes[int(row[0])].distance_to(local)>=0 else row[2]
    steps+=1
   if index<0 and int(bsp.leaves[-index-1])==-2:return true
 elif not pen.brushes.is_empty():
  for brush in pen.brushes:
   if not brush.bounds.has_point(p):continue
   var inside:=true
   for plane in brush.planes:
    if plane.distance_to(p)>0:inside=false;break
   if inside:return true
 return false
func clear_at(game,p: Vector3) -> bool:
 if solid_at(game,p):return false
 sphere.radius=.45
 var query:=PhysicsShapeQueryParameters3D.new()
 query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,p);query.collision_mask=1;query.margin=.08
 return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func clear_position(game,wanted: Vector3) -> Vector3:
 if clear_at(game,wanted):safe_position=wanted;has_safe_position=true;return wanted
 clearance_corrections+=1
 # Search upward first to preserve the overhead angle; reject interior BSP solids too.
 for height in [.6,1.2,2.,3.,4.5,6.,9.,12.]:
  var candidate: Vector3=wanted+Vector3.UP*height
  if clear_at(game,candidate):safe_position=candidate;has_safe_position=true;return candidate
 if has_safe_position and clear_at(game,safe_position):return safe_position
 for distance in [12.,9.,6.,3.]:
  for heading in [HEADING,Vector3(-.5,.707,.5),Vector3(.5,.707,-.5),Vector3(-.5,.707,-.5)]:
   var candidate: Vector3=focus+heading*distance
   if clear_at(game,candidate):safe_position=candidate;has_safe_position=true;return candidate
 clearance_failures+=1
 return safe_position if has_safe_position else wanted
