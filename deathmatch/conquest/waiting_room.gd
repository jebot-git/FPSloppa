extends Node3D
## One local room per waiting client. No battle actor or worker simulates this room.
const ORIGIN=Vector3(0,-2048,0)
var game
func setup(arena) -> void:
	game=arena;position=ORIGIN
	var mine: int=game.multiplayer.get_unique_id()
	var team: int=game.players.get(mine,{}).get("team",0)
	var accent:=Color(.85,.12,.10) if team==0 else Color(.1,.4,1)
	box(Vector3(0,-.15,0),Vector3(12,.3,12),Color(.07,.09,.12))
	box(Vector3(0,5.1,0),Vector3(12,.2,12),Color(.035,.05,.07))
	for side in [-1,1]:
		box(Vector3(side*6,2.5,0),Vector3(.3,5,12),Color(.045,.06,.09))
		box(Vector3(0,2.5,side*6),Vector3(12,5,.3),Color(.045,.06,.09))
		box(Vector3(side*5.78,.25,0),Vector3(.06,.12,11.4),accent,false)
		box(Vector3(0,.25,side*5.78),Vector3(11.4,.12,.06),accent,false)
		box(Vector3(side*4,.5,2.5),Vector3(1.2,1,3),Color(.12,.15,.20))
	if not game.headless:
		var label:=Label3D.new();label.text="REINFORCEMENT HOLDING ROOM\n\nNo friendly deployment slot is available.\nYou will return automatically when one opens."
		label.font_size=40;label.pixel_size=.006;label.position=Vector3(0,2.6,-5.7);label.modulate=Color(.8,.9,1);add_child(label)
	if game.fighters.has(mine):
		var actor=game.fighters[mine];actor.position=ORIGIN+Vector3(0,.1,2);actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view();actor.prediction.clear();actor.reset_physics_interpolation();actor.show_alive(false,true)
		game.players[mine].dead=true;game.players[mine].hp=0;game.local_yaw=0;game.local_pitch=0
		if game.is_vr():game.xr_rig.on_spawn()
func box(at: Vector3,size: Vector3,color: Color,solid: bool=true) -> void:
	var node:=Node3D.new();add_child(node);node.position=at
	if solid:
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;node.add_child(body)
		var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider)
	if game.headless:return
	var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=size;mesh.mesh=cube
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(mesh)
func tick(delta: float) -> void:
	var mine: int=game.multiplayer.get_unique_id()
	if not game.fighters.has(mine):return
	var actor=game.fighters[mine];var command: Dictionary=game._local_command()
	game._update_crouch(mine,command.get("xr",{}),command)
	actor.simulate(command.get("move",Vector2.ZERO),game.local_yaw,true,delta,command.get("jump",false))
	if game.is_vr():
		var room=game.RoomScale.validate(command.get("room"),command.get("xr",{}))
		var shift=game.RoomScale.move_capsule(actor,room,game.local_yaw,delta);game.xr_rig.compensate_room_move(shift)
	# Local comfort movement has no network input, weapons, pickups or capture effects.
	if actor.position.y<ORIGIN.y-2:actor.position=ORIGIN+Vector3(0,.1,2);actor.velocity=Vector3.ZERO;actor.reset_view()
