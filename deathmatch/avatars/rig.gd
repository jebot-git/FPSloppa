extends Node3D
## Original UT99 vertex animation. Shared mesh/skin/frame texture; instance uniforms only.
const Art=preload("res://deathmatch/art.gd")
var avatar_hash:=""
var unarmed:=false
var target_xr_pose:Dictionary={}
var speed:=0.0
var movement:=Vector3.ZERO
var stance:="stand"
var collider_height:=1.65
var grounded:=true
var aim_pitch:=0.0
var body_height:=1.7
var dead:=false:
	set(value):
		if dead!=value:death_time=0.0
		dead=value
var death_time:=0.0
var preview_mode:=-1
var weapon_id:=-1
var gun:Node3D
var offhand_gun:Node3D
var visual:MeshInstance3D
var arm_profile:Dictionary={}
var tracked_arms_enabled:=true
var tracked_arms_active:=false
var arm_update_ms:=0.0
var clips:Array=[]
var clip_name:=""
var time:=0.0
var firing:=0.0
var selected_sequence:="" # Preview can select any original clip.
func configure(data:Dictionary) -> void:
	clips=data.clips;arm_profile=data.get("arm_profile",{})
	visual=MeshInstance3D.new();visual.mesh=data.mesh;add_child(visual)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func set_first_person(value:bool) -> void:
	visible=not value # No head hiding, skeleton, body IK or expression channels.
var weapon_rules:="doom"
func set_weapon(id:int,rules_override:String="") -> void:
	var arena=get_parent().get_parent() if get_parent() else null
	var rules:String=rules_override if not rules_override.is_empty() else arena.match_mode.fortress.art_rules(get_parent().peer_id,id) if arena and "armory" in arena else "doom"
	if weapon_id==id and weapon_rules==rules:return
	weapon_id=id;weapon_rules=rules
	if is_instance_valid(gun):gun.free()
	if is_instance_valid(offhand_gun):offhand_gun.free()
	gun=Art.weapon(id,2,rules);add_child(gun)
	offhand_gun=Art.weapon(2) if id==2 and rules=="doom" else null
	if offhand_gun:add_child(offhand_gun)
func fire(_offhand:bool=false) -> void:firing=.3
func hurt(_direction:Vector3,_amount:float) -> void:pass
func choose_clip() -> Dictionary:
	var names:Array=[]
	if not selected_sequence.is_empty():names=[selected_sequence]
	elif dead:names=["Dead1","Death","Dead2"]
	elif preview_mode==3 or (preview_mode<0 and firing>0 and speed<=.1):names=["StillFrRp","Fire","StillFrSm","AimLg"]
	elif preview_mode<0 and not grounded:names=["JumpLg","JumpSm","Jump"]
	elif preview_mode<0 and stance in ["crouch","prone"]:names=["DuckWlkL","DuckWlkS","Crouch"]
	elif preview_mode==2 or speed>3:names=["RunLg","RunSm","Run"]
	elif preview_mode==1 or speed>.1:names=["WalkLg","WalkSm","Walk"]
	elif not grounded:names=["JumpLg","JumpSm","Jump"]
	elif stance in ["crouch","prone"]:names=["DuckWlkL","DuckWlkS","Crouch"]
	else:names=["Breath1","Breath2","Idle","StillLg","StillSm"]
	for name in names:
		for clip in clips:
			if str(clip.name).to_lower()==str(name).to_lower():return clip
	# Unknown clips fall back to a stable original frame rather than playing All.
	for clip in clips:
		if str(clip.name).to_lower()!="all":return clip
	return clips[0]
func _process(delta:float) -> void:
	firing=maxf(0,firing-delta)
	if dead:death_time+=delta
	if visual==null:return
	var clip:=choose_clip()
	if clip_name!=clip.name:clip_name=clip.name;time=0
	time+=delta
	var frame:=minf(time*float(clip.fps),float(clip.count)-1) if dead else fposmod(time*float(clip.fps),float(clip.count))
	var a:=floori(frame);var b:=mini(a+1,int(clip.count)-1) if dead else (a+1)%int(clip.count)
	var frames:=Vector3(int(clip.start)+a,int(clip.start)+b,frame-a)
	visual.set_instance_shader_parameter("animation_frames",frames)
	var arm_start:=Time.get_ticks_usec()
	tracked_arms_active=preload("res://deathmatch/avatars/controller_arms.gd").update(visual,arm_profile,target_xr_pose if tracked_arms_enabled and not dead else {},frames)
	arm_update_ms=(Time.get_ticks_usec()-arm_start)/1000.0
	visual.scale=Vector3.ONE
	visual.rotation=Vector3.ZERO
	if stance=="prone" and not dead:
		visual.rotation.x=-PI/2;visual.position=Vector3(0,.3,.4)
	else:visual.position=Vector3.ZERO
	if not dead and stance=="crouch" and not (clip_name.to_lower().begins_with("duck") or clip_name.to_lower()=="crouch"):visual.scale.y=.65
	for held in [gun,offhand_gun]:
		if not is_instance_valid(held):continue
		held.visible=not unarmed and not dead
		var offhand:bool=held==offhand_gun
		var id:int=2 if offhand else weapon_id
		var pose_key:="offhand_weapon" if offhand else "weapon"
		if target_xr_pose.has(pose_key):
			held.transform=Art.held_transform(target_xr_pose[pose_key],id,Art.VR_SCALE,weapon_rules)
		else:
			var grip:=Transform3D(Basis(Vector3.RIGHT,aim_pitch),Art.desktop_hand(offhand,aim_pitch,0,offhand))
			held.transform=Art.held_transform(grip,id,.48,weapon_rules)
