extends Node3D
## Cached, flush readout on the T2 launcher's authored rear-facing monitor.
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Lock=preload("res://deathmatch/conquest/classes/vehicle_lock.gd")
var viewport:SubViewport
var label:Label
var screen:MeshInstance3D
var last_text:=""
func setup(model:Node3D=null)->void:
 name="GuidanceMonitor"
 viewport=SubViewport.new();viewport.size=Vector2i(320,320);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
 var background:=ColorRect.new();background.color=Color("07181c");background.size=viewport.size;viewport.add_child(background)
 label=Label.new();label.position=Vector2(12,12);label.size=Vector2(296,296);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_override("font",preload("res://deathmatch/ui/cq/theme.gd").FONT);label.add_theme_font_size_override("font_size",42);viewport.add_child(label)
 screen=MeshInstance3D.new();screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 screen.mesh=QuadMesh.new()
 var material:=ShaderMaterial.new();material.shader=preload("res://deathmatch/vr/weapon_display.gdshader");material.set_shader_parameter("readout",viewport.get_texture());screen.material_override=material;add_child(screen)
 if model:update_guidance(model,{}, {},0.)
static func mount(model:Node3D)->Transform3D:
 var data:=Models.metadata(int(model.get_meta("cq_weapon",-1)),"cq_technician")
 var at:Array=data.get("monitor_position",[0.,0.,0.]);var rotation:Array=data.get("monitor_rotation",[0.,0.,0.])
 return model.global_transform*Transform3D(Basis.from_euler(Vector3(rotation[0],rotation[1],rotation[2])),Vector3(at[0],at[1],at[2]))
static func latest_flight(projectiles:Dictionary,owner_id:int,serial:int)->float:
 # Presented projectile life is seconds remaining, not the authority's owner-life ID.
 var newest:=-1;var remaining:=-1.
 for key in projectiles:
  var p:Dictionary=projectiles[key]
  if p.get("owner",0)!=owner_id or p.get("weapon",-1)!=11 or float(p.get("life",0.))<=0.:continue
  if p.get("extra",{}).get("owner_life",serial)!=serial:continue
  var seconds:=maxf(0.,float(p.life)-float(p.get("visual_age",0.)))
  if seconds<=0.:continue
  if int(key)>newest:newest=int(key);remaining=seconds
 return remaining
static func guidance_text(lock:Dictionary,magazine:Dictionary,clock:float,flight_remaining:float=-1.)->String:
 var status:="SEARCH"
 if lock.get("ready",false):status="LOCKED"
 elif not lock.is_empty():status="ACQUIRING %03d%%"%clampi(roundi(float(lock.get("elapsed",0.))/Lock.DWELL*100.),0,100)
 if flight_remaining>0.:
  return status+"\nIN FLIGHT\n%.1f s LEFT"%flight_remaining
 if magazine.get("reloading",-1)==11:return status+"\nNEW PACK\n%.1f s"%maxf(0.,float(magazine.get("reload_at",clock))-clock)
 if magazine.get("cycling",-1)==11:return status+"\nRECHARGING\n%.1f s"%maxf(0.,float(magazine.get("cycle_at",clock))-clock)
 if magazine.get("clips",{}).get(11,3)<=0:return status+"\nPACK EMPTY"
 if lock.get("ready",false):return "LOCKED\nHOMING READY"
 if not lock.is_empty():return "ACQUIRING\n%03d%%\nHOLD AIM"%clampi(roundi(float(lock.get("elapsed",0.))/Lock.DWELL*100.),0,100)
 return "SEARCH\nVEHICLE LOCK\n%d m"%int(Lock.RANGE)
func update_guidance(model:Node3D,lock:Dictionary,magazine:Dictionary,clock:float,show_panel:bool=true,flight_remaining:float=-1.)->void:
 update_display(model,guidance_text(lock,magazine,clock,flight_remaining),not lock.is_empty() and not lock.get("ready",false),show_panel)
func update_display(model:Node3D,text:String,acquiring:bool,show_panel:bool)->void:
 var valid_model:bool=is_instance_valid(model) and int(model.get_meta("cq_weapon",-1))==11
 visible=show_panel and valid_model
 if not visible:return
 var data:=Models.metadata(11,"cq_technician")
 if not data.get("guidance_monitor",false):hide();return
 # Child mounting follows tracking/recoil without a render-frame lag.
 if get_parent()!=model:reparent(model,false)
 var at:Array=data.monitor_position;var rotation:Array=data.get("monitor_rotation",[0.,0.,0.])
 transform=Transform3D(Basis.from_euler(Vector3(rotation[0],rotation[1],rotation[2])),Vector3(at[0],at[1],at[2]))
 var size:Array=data.monitor_size;screen.mesh.size=Vector2(size[0],size[1])
 var formatted:=text.replace(" · ","\n").strip_edges();var signature:=formatted+str(acquiring)
 if signature==last_text:return
 last_text=signature;label.text=formatted;label.add_theme_color_override("font_color",Color("ffbe73") if acquiring else Color("73e5df"));viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
