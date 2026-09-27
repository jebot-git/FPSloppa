extends Node3D
const Model=preload("res://deathmatch/pickups/bomb_model.gd")
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
const Art=preload("res://deathmatch/art.gd")
var rules
var bomb
var preview: Node3D
var tools: Dictionary={}
var beep: AudioStreamPlayer3D
var next_beep:=0.0
func setup(value):
	rules=value;name="DefusalObjectives"
	bomb=Model.new();add_child(bomb)
	# Site callouts are painted into every DE map. Do not add floating labels or
	# fixed plant-point markers: the bomb can mount anywhere in the site's bounds.
	preview=Node3D.new();add_child(preview);preview.hide()
	var material:=Art.material(Color("83c9bc"),1,0);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for x in [-.155,.155]:Art.box(preview,Vector3(x,0,-.094),Vector3(.008,.38,.008),material)
	for y in [-.19,.19]:Art.box(preview,Vector3(0,y,-.094),Vector3(.318,.008,.008),material)
	beep=AudioStreamPlayer3D.new();beep.bus="ArenaEffects" if AudioServer.get_bus_index("ArenaEffects")>=0 else "Master";beep.max_distance=35;beep.volume_db=-15
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var data:=PackedByteArray();data.resize(2206)
	for i in 1103:data.encode_s16(i*2,roundi(sin(i*TAU*1100/22050.0)*6000*(1.0-i/1103.0)))
	stream.data=data;beep.stream=stream;add_child(beep)
func tool_for(id: int) -> Node3D:
	if not tools.has(id):tools[id]=Model.cutters();tools[id].hide();add_child(tools[id])
	return tools[id]
func snip(id: int):tool_for(id).snip()
func update():
	var game=rules.game;var mine: int=game.multiplayer.get_unique_id()
	bomb.visible=rules.phase in ["prepare","live","post"]
	bomb.global_transform=rules.bomb_pose()
	if rules.carrier==mine and game.is_vr():bomb.global_transform=game.xr_rig.global_transform*(Contact.held(game.xr_rig.sample_pose()) if rules.held else Contact.carried(game.xr_rig.sample_pose()))
	var armed: bool=rules.armed_until>game.clock
	var text: String="ARM %d [%d/4]"%[rules.arm_code[mini(rules.arm_index,3)],rules.arm_index]
	if armed:text="ARMED · %ds"%ceili(rules.armed_until-game.clock)
	if rules.planted:text="%d [%d/8]  %02d"%[rules.defuse_code[mini(rules.defuse_index,7)],rules.defuse_index,ceili(maxf(0,rules.fuse_end-game.clock))]
	if rules.phase=="post":text=rules.message
	bomb.update_display(text,armed or rules.planted,rules.cut_mask)
	bomb.highlight(-1)
	if game.is_vr() and (rules.carrier==mine and rules.held or rules.planted and rules.role(mine)==1):
		var pose: Dictionary=game.xr_rig.sample_pose()
		if pose.has("index_tip"):
			var at: Vector3=bomb.global_transform.affine_inverse()*(game.xr_rig.global_transform*Contact.fingertip(pose))
			bomb.highlight(Contact.key_at(at))
	preview.hide()
	if armed and rules.carrier==mine and rules.held and rules.phase=="live":
		var candidate: Dictionary=rules.placement(mine)
		if not candidate.is_empty():preview.global_transform=candidate.pose;preview.show()
	if rules.planted and rules.phase=="live" and game.clock>=next_beep:
		beep.global_position=rules.bomb_position;beep.play();next_beep=game.clock+clampf((rules.fuse_end-game.clock)/40.0,.15,1.0)
	if not rules.planted:next_beep=0
	for id in tools.keys():
		if not game.players.has(id):tools[id].queue_free();tools.erase(id)
	for id in game.players:
		if not rules.account(id).kit:
			if tools.has(id):tools[id].hide()
			continue
		var node:=tool_for(id);node.visible=rules.alive(id) and rules.phase in ["prepare","live"]
		var pose: Dictionary=game.players[id].xr
		var frame: Transform3D=rules.base_pose(id)
		if id==mine and game.is_vr():pose=game.xr_rig.sample_pose();frame=game.xr_rig.global_transform
		node.global_transform=frame*(pose.get("weapon",Transform3D(Basis.IDENTITY,Vector3(.15,1.0,-.4))) if rules.account(id).tool else Contact.tool_carried(pose))
