extends Node3D
## Local affordances for the authoritative CS reload sampler. The pouch and held
## ammo are cosmetic; only validated hand motions on the server change the clip.
const Reload=preload("res://deathmatch/counterstrike/reload_state.gd")
const Models=preload("res://deathmatch/counterstrike/models.gd")
const Art=preload("res://deathmatch/art.gd")
const Pouch=preload("res://deathmatch/weapons/cs16/magazine_pouch.scn")
var rig
var bag: Node3D
var bag_ammo: Node3D
var carried: Node3D
var hint: Label3D
var target: MeshInstance3D
var last_row: Array=[]
var slot:=-1
var debris: Array=[]
var pump_held:=false
var pump_basis:=Basis.IDENTITY
func setup(value):
	rig=value;name="PhysicalReload"
	bag=Pouch.instantiate();add_child(bag)
	preload("res://deathmatch/maps/filtering.gd").new().apply(bag,int(rig.game.presentation.get("texture_filter",2)))
	hint=Label3D.new();hint.font_size=22;hint.pixel_size=.001;hint.outline_size=4;hint.no_depth_test=true;hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED;hint.modulate=Color("edd3a3");add_child(hint)
	target=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.030;ring.outer_radius=.034;target.mesh=ring;target.material_override=Art.material(Color("91d9bf"),1,0);add_child(target)
	reset()
func reset():
	last_row=[];slot=-1;pump_held=false
	if bag:bag.hide();hint.hide();target.hide()
	if is_instance_valid(carried):carried.hide()
	for item in debris:
		if is_instance_valid(item.node):item.node.queue_free()
	debris.clear()
func claims_hand(primary: Transform3D,support: Transform3D,grip: bool) -> bool:
	if not grip or rig.game.armory.effective()!="cs16":return false
	var row: Array=rig.game.variant_combat.cs.status(rig.game.multiplayer.get_unique_id())
	if row.size()!=Reload.ROW_SIZE or not row[5]&Reload.PHYSICAL:return false
	var w: int=row[1]
	if row[8]>0 or row[5]&(Reload.RACK_GRIP|Reload.COVER_GRIP|Reload.HK_LOCK|Reload.PUMP_HOLD|Reload.MAG_GRIP) or not row[5]&Reload.CHAMBERED:return true
	var d: Dictionary=rig.game.armory.data(w)
	if Reload.wants_pouch(w,{"mag":row[5]&Reload.MAGAZINE!=0},row[2],rig.game.local_state().ammo[d.ammo],d.magazine):
		var pose:={"head":rig.origin.transform*rig.head.transform,"left_handed":rig.left_handed,"body":rig.tracking.sample()}
		if Reload.Hip.recovery_contains(pose,rig.origin.transform*support.origin):return true
	var gun_pose:=Art.held_transform(primary,w,Art.VR_SCALE,"cs16")
	if row[5]&Reload.MAGAZINE and Reload.magazine_contact(w,float(row[7])/100,gun_pose,support.origin):return true
	if w==8 and support.origin.distance_to(gun_pose*Reload.cover_point(float(row[7])/100))<Reload.GRAB_RADIUS*1.4:return true
	if Reload.handguard_first(w,gun_pose.affine_inverse()*support.origin):return false
	return w!=3 and support.origin.distance_to(gun_pose*Reload.RACK_POINTS[w])<Reload.GRAB_RADIUS*1.4
func busy() -> bool:
	return pump_held or last_row.size()==Reload.ROW_SIZE and (last_row[8]>0 or last_row[5]&(Reload.RACK_GRIP|Reload.COVER_GRIP|Reload.BELT_GRIP|Reload.MAG_GRIP)!=0)
func support_weapon(primary: Transform3D,support: Transform3D,grip: bool,primary_grip: bool,valid: bool) -> Transform3D:
	if not valid or not rig.game.active or rig.game.armory.effective()!="cs16" or not grip or primary_grip:pump_held=false;return primary
	var row: Array=rig.game.variant_combat.cs.status(rig.game.multiplayer.get_unique_id())
	if row.size()!=Reload.ROW_SIZE or row[1]!=3 or row[5]&Reload.PHYSICAL==0:pump_held=false;return primary
	if not pump_held:
		var gun_pose:=Art.held_transform(primary,3,Art.VR_SCALE,"cs16")
		var automatic: bool=rig.pump_auto_transfer and rig.support_holding()
		if not automatic and (row[5]&Reload.CHAMBERED or support.origin.distance_to(gun_pose*Reload.RACK_POINTS[3])>Reload.GRAB_RADIUS):return primary
		pump_basis=support.basis.inverse()*primary.basis;pump_held=true
	return preload("res://deathmatch/vr/pump_hold.gd").weapon(support,support.basis*pump_basis,float(row[6])/100)
func eject_visual(w: int,from_hand: bool=false):
	var body:=RigidBody3D.new();body.collision_layer=0;body.collision_mask=1;body.mass=.15
	add_child(body);body.top_level=true
	var source:=Transform3D(rig.gun.global_basis,rig.gun.to_global(Reload.MAG_POINTS[w]))
	if from_hand:
		var hand: XRController3D=rig.right if rig.left_handed else rig.left
		source=Models.ammo_pose(hand.global_transform,w,hand==rig.left)
	# Physics owns an unscaled body. Keep the source visual scale on its child;
	# putting it on RigidBody3D is lost when the next simulation pose arrives.
	body.global_transform=Transform3D(source.basis.orthonormalized(),source.origin)
	var model:=Models.ammunition(w);body.add_child(model)
	model.basis=body.global_basis.inverse()*source.basis
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.08,.12,.10) if w==8 else Vector3(.025,.10,.03);collider.shape=shape;body.add_child(collider)
	body.linear_velocity=Vector3.DOWN*.45;body.angular_velocity=Vector3(.4,.2,.3)
	debris.append({"node":body,"time":2.5})
	while debris.size()>4:
		var oldest: Dictionary=debris.pop_front();oldest.node.queue_free()
func update(delta: float,valid: bool):
	for i in range(debris.size()-1,-1,-1):
		debris[i].time-=delta
		if debris[i].time<=0:debris[i].node.queue_free();debris.remove_at(i)
	var game=rig.game
	var row: Array=game.variant_combat.cs.status(game.multiplayer.get_unique_id()) if game.active and game.armory.effective()=="cs16" else []
	valid=valid and row.size()==Reload.ROW_SIZE and row[1]>0 and row[5]&Reload.PHYSICAL!=0 and is_instance_valid(rig.gun) and rig.gun.visible
	bag.visible=false;hint.visible=false;target.visible=false
	if is_instance_valid(carried):carried.hide()
	if not valid:last_row=[];pump_held=false;return
	var pose: Dictionary=rig.sample_pose()
	if pose.is_empty() or not pose.has("offhand_weapon"):last_row=[];return
	var w: int=row[1];var same: bool=last_row.size()==Reload.ROW_SIZE and last_row[0]==row[0] and last_row[1]==w
	if same:
		if last_row[5]&Reload.MAGAZINE and not row[5]&Reload.MAGAZINE:
			if row[8]!=Reload.REMOVED_MAG:eject_visual(w)
			rig.feedback(.28,.06,true)
		elif last_row[8]==Reload.REMOVED_MAG and row[8]!=Reload.REMOVED_MAG and not row[5]&Reload.MAGAZINE:eject_visual(w,true)
		if last_row[8]!=row[8] or last_row[5]&Reload.CHAMBERED!=row[5]&Reload.CHAMBERED:rig.feedback(.25,.05,true)
	if slot!=w:
		if is_instance_valid(bag_ammo):bag_ammo.free()
		if is_instance_valid(carried):carried.free()
		bag_ammo=Models.ammunition(w);bag_ammo.scale=Vector3.ONE*Art.VR_SCALE;bag_ammo.position.y=.08;bag.add_child(bag_ammo)
		carried=Models.ammunition(w);add_child(carried);slot=w
	last_row=row.duplicate()
	var hand: XRController3D=rig.right if rig.left_handed else rig.left
	var p:={"mag":row[5]&Reload.MAGAZINE!=0}
	var d: Dictionary=game.armory.data(w);var total: int=game.local_state().ammo[d.ammo]
	bag.visible=Reload.wants_pouch(w,p,row[2],total,d.magazine)
	bag.global_transform=rig.global_transform*Reload.pouch(pose)
	bag_ammo.visible=row[8]==0
	carried.visible=row[8]>0 and row[8]!=3
	if carried.visible:carried.global_transform=Models.ammo_pose(hand.global_transform,w,hand==rig.left)
	if carried.visible and row[8]==Reload.REMOVED_MAG:
		hint.text="%d rounds"%row[11];hint.global_position=carried.global_position+Vector3.UP*.12;hint.show()
	# Only a held magazine's round count floats above it; controls have no guides.
	var action=rig.gun.get_node_or_null("ChamberAction")
	if action and w==8 and row[8]==3:action.belt_endpoint=rig.gun.to_local(hand.global_position);action.pose(1.0)
