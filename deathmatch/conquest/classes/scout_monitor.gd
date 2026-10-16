extends Node3D
## A sideways weapon-mounted optic, on the support-hand side, with no eye box.
const OPTIC_LAYER:=1<<19
var model:Node3D
var viewport:SubViewport
var camera:Camera3D
var game
var magnification:=3.
func setup(weapon:Node3D,data:Dictionary)->void:
 model=weapon;magnification=data.get("monitor_zoom",3.)
 var at:Array=data.monitor_anchor;position=Vector3(at[0],at[1],at[2])
 var size:=Vector2(data.monitor_size[0],data.monitor_size[1])
 var art=preload("res://deathmatch/art.gd")
 art.box(self,Vector3(0,0,-.006),Vector3(size.x+.012,size.y+.012,.012),art.material(Color("26343e"),.4))
 art.box(self,Vector3(-position.x*.5,-.02,-.018),Vector3(absf(position.x),.014,.02),art.material(Color("26343e"),.4))
 viewport=SubViewport.new();viewport.size=Vector2i(384,240);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.audio_listener_enable_3d=false;add_child(viewport)
 camera=Camera3D.new();camera.near=.025;camera.far=1600.;camera.cull_mask=((1<<20)-1)&~OPTIC_LAYER&~(1<<18);camera.compositor=Compositor.new();viewport.add_child(camera)
 var lens:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=size;lens.mesh=mesh;lens.layers=OPTIC_LAYER;lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(lens)
 var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.albedo_texture=viewport.get_texture();lens.material_override=finish
 var reticle:=Control.new();reticle.set_script(preload("res://deathmatch/conquest/classes/scout_monitor_reticle.gd"));viewport.add_child(reticle)
func _process(_delta:float)->void:
 if not is_instance_valid(game):
  var parent:Node=get_parent()
  while parent:
   if parent.has_method("local_state"):game=parent;break
   parent=parent.get_parent()
 if not is_instance_valid(game) or not game.active:return
 var mine:Dictionary=game.local_state();var shown:bool=not mine.get("dead",true) and mine.get("weapon",-1)==10 and not game.menu_open
 if game.is_vr():shown=shown and game.xr_rig.gun==model and model.visible;position.x=absf(position.x)*(1. if game.xr_rig.left_handed else -1.)
 visible=shown;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
 if not shown:return
 viewport.world_3d=get_world_3d();camera.global_transform=Transform3D(model.global_basis.orthonormalized(),model.to_global(model.get_meta("muzzle")))
 camera.fov=preload("res://deathmatch/vr/sniper_scope.gd").zoom_fov(70.,magnification);camera.make_current()
