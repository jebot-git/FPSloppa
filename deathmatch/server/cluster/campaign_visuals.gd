extends Node3D
## Baked-map overlay: unlit meshes and labels only; no real-time lights.
@export var metadata: Dictionary={}
const RED=Color(1,.16,.21)
const BLUE=Color(.12,.55,1)
const NEUTRAL=Color(.48,.55,.62)
var current: Dictionary={}
func tint(team: int) -> Color:return RED if team==0 else BLUE if team==1 else NEUTRAL
func surface(color: Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color;m.cull_mode=BaseMaterial3D.CULL_DISABLED;return m
func hologram(color: Color) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=preload("res://deathmatch/conquest/gate.gdshader");m.set_shader_parameter("tint",color);return m
func label_at(key: String,text: String,point: Vector3,size: int=32) -> Label3D:
	var label:=Label3D.new();label.name=key;label.text=text;label.position=point;label.font_size=size;label.pixel_size=.015;label.no_depth_test=false;label.outline_size=6;add_child(label);return label
func box_at(key: String,point: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=key;var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=point;node.material_override=surface(color);add_child(node);return node
func _ready() -> void:
	if get_child_count()==0:build()
	var initial:={"owners":{},"points":{},"locks":{},"scores":[0,0],"history":[],"epoch":1}
	initial.owners["d%02d"%int(metadata.get("asset_id",0))]=metadata.get("initial_owner",-1)
	apply_campaign(initial)
func build() -> void:
	var role: String=metadata.get("campaign_role","")
	if role=="hub":
		box_at("ScoreboardBack",Vector3(0,4.6,-22),Vector3(16,7,.25),Color(.02,.03,.045))
		label_at("Scoreboard","",Vector3(0,4.6,-21.8),40)
		for target in metadata.get("terminals",{}):
			var p: Array=metadata.terminals[target].exit
			box_at("Terminal_"+target,Vector3(p[0],1.85,p[2]),Vector3(3.2,3.6,.035),NEUTRAL)
			label_at("TerminalLabel_"+target,"",Vector3(p[0],4.4,p[2]),24)
	elif int(metadata.get("threshold",0))>0:
		var ring:=MeshInstance3D.new();ring.name="CaptureRing";var torus:=TorusMesh.new();torus.inner_radius=7.8;torus.outer_radius=8;torus.rings=32;torus.ring_segments=8;ring.mesh=torus;ring.position.y=.25;ring.material_override=surface(NEUTRAL);add_child(ring)
		box_at("FlagPole",Vector3(0,2.4,0),Vector3(.12,4.2,.12),NEUTRAL)
		box_at("Flag",Vector3(.8,3.6,0),Vector3(1.6,.9,.025),NEUTRAL)
		label_at("CaptureLabel","",Vector3(0,5.2,0),26)
func apply_campaign(state: Dictionary,team: int=-1,links: Dictionary={}) -> void:
	current=state
	var id:="d%02d"%int(metadata.get("asset_id",0));var owners: Dictionary=state.get("owners",{});var owner:=int(owners.get(id,-1))
	var flag:=get_node_or_null("Flag") as MeshInstance3D
	if flag:
		flag.material_override=surface(tint(owner));get_node("CaptureRing").material_override=surface(tint(owner))
		var points: Array=state.get("points",{}).get(id,[0,0]);var lock: Dictionary=state.get("locks",{}).get(metadata.get("homebase",""),{})
		get_node("CaptureLabel").text=metadata.name+"\n"+("RED" if owner==0 else "BLUE" if owner==1 else "NEUTRAL")+" · %d points\nRed %.1f   Blue %.1f"%[int(metadata.threshold),points[0],points[1]]+("\nPERIMETER LOCKDOWN · %ds"%maxi(0,int(lock.until-float(state.get("at",0)))) if not lock.is_empty() else "")
	if has_node("Scoreboard"):
		var score: Array=state.get("scores",[0,0]);var text:="CONCORD · NO FIRE\nCAMPAIGN %d\nRED %d / 20     BLUE %d / 20\nHomebases score at 00:00 UTC"%[int(state.get("epoch",1)),score[0],score[1]]
		var history: Array=state.get("history",[])
		for result in history.slice(maxi(0,history.size()-4)):
			text+="\nCampaign %d · %s · %d–%d"%[int(result.epoch),"RED" if int(result.winner)==0 else "BLUE" if int(result.winner)==1 else "DRAW",result.scores[0],result.scores[1]]
		get_node("Scoreboard").text=text
		for target in metadata.get("terminals",{}):
			var controlled:=int(owners.get(target,-1));get_node("Terminal_"+target).material_override=hologram(tint(controlled))
			var available: bool=links.get(target,{}).get("open",false) and controlled==team
			get_node("TerminalLabel_"+target).text="RELAY "+target.trim_prefix("d")+"\n"+("WALK THROUGH" if available else "NEUTRAL" if controlled<0 else "RED CONTROL" if controlled==0 else "BLUE CONTROL")
