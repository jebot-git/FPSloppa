extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.set_process(false);g.set_physics_process(false)
 for row in g.map_catalog:
  if row.id.begins_with("custom_"):continue
  g._load_map(row.id)
  var count:=0;var hidden:=true;var collision:=true
  for node in g.get_node("Map").find_children("*","Area3D",true,false):
   if not node.get("attributes") or not str(node.attributes.get("classname","")).begins_with("trigger_"):continue
   count+=1
   for mesh in node.find_children("*","GeometryInstance3D",true,false):hidden=hidden and not mesh.is_visible_in_tree()
   collision=collision and node.collision_mask==2 and node.find_children("*","CollisionShape3D",true,false).size()>0
  check(count>0 and hidden and collision,row.id+" trigger meshes hidden while volumes remain active")
 g._add_player(1,"Local")
 g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
 g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
 g.xr_rig.set_process(false)
 g.headless=false;g.spatial.setup(g);g.active=true;g.menu_open=false
 g.effects.enabled=false
 g.players[1].invulnerable=0
 g._damage(1,1,5,"test")
 g.xr_rig._process(0)
 check(g.hurt_flash>0 and g.xr_rig.damage_overlay.visible,"Small local hit immediately shows VR feedback")
 check(g.effects.local_pain is AudioStreamPlayer and g.effects.local_pain.playing,"Local hit has unoccluded headset sound")
 var before:float=g.hurt_flash
 g._hurt_fx(2,Vector3.ZERO,Vector3.ZERO,10,false,false,1)
 check(g.hurt_flash==before,"Other players' hits do not tint local view")
 g._process(1);g.xr_rig._process(0)
 check(g.hurt_flash==0 and not g.xr_rig.damage_overlay.visible,"Hit overlay fades away")
 g.hurt_flash=.3;g.xr_rig.focused=false;g.xr_rig._process(0)
 check(not g.xr_rig.damage_overlay.visible,"Hit overlay hidden when headset loses focus")
 g.free()
 # Audio playback release runs on the audio thread after node teardown.
 await create_timer(.25).timeout
 print("MAP_VISUALS_FEEDBACK_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
