extends Node3D
const State=preload("res://deathmatch/vr/weapon_wheel_state.gd")
const View=preload("res://deathmatch/ui/weapon_wheel.gd")
const Shop=preload("res://deathmatch/counterstrike/buy_wheel.gd")
const PANEL_SIZE:=.38
const HAND_HEIGHT:=.23
var input=State.new()
var rig_ref: WeakRef
var rig:
	get:return rig_ref.get_ref()
var viewport: SubViewport
var view: Control
var entries: Array=[]
var shopping:=false
var tribes_shop:=false
var tribes_inventory=preload("res://deathmatch/tribes/buy_wheel.gd").new()
var page:=0

func setup(owner_rig: Node) -> void:
	rig_ref=weakref(owner_rig);name="WeaponWheel";hide()

func follow_hand() -> void:
	# Grip position follows handedness; joystick sectors stay upright and readable.
	# The wheel shares the controllers' XR origin, including seated/crouch offsets.
	var hand: XRController3D=rig.left if rig.left_handed else rig.right
	position=hand.position+Vector3.UP*HAND_HEIGHT
	var to_head: Vector3=rig.head.position-position
	if to_head.length_squared()<.0001:return
	var up:=Vector3.FORWARD if absf(to_head.normalized().dot(Vector3.UP))>.98 else Vector3.UP
	basis=Basis.looking_at(to_head,up,true)

func inventory() -> Array:
	var game=rig.game;var state: Dictionary=game.local_state()
	if tribes_shop:return tribes_inventory.rows(game.match_mode.tribes,game.multiplayer.get_unique_id())
	if shopping:return Shop.rows(game.match_mode.defusal,game.multiplayer.get_unique_id(),page)
	var owned: Array=state.get("owned",[]).duplicate();owned.sort()
	var rows: Array=[]
	for id in owned:
		if not game.armory.valid(id) or rows.any(func(row):return row.id==id):continue
		var data: Dictionary=game.match_mode.fortress.weapon_data(game.multiplayer.get_unique_id(),id)
		var ammo: int=game.match_mode.tribes.amount(game.multiplayer.get_unique_id(),id) if game.match_mode.tribes.enabled() else -1 if data.ammo<0 else state.get("ammo",[0,0,0,0])[data.ammo]
		rows.append({"id":id,"name":data.name,"icon":("TRIBES "+data.name) if game.match_mode.tribes.enabled() else data.name,"ammo":ammo,"usable":ammo<0 or ammo>=data.cost})
	rows.append_array(game.match_mode.defusal.utility.inventory(game.multiplayer.get_unique_id()))
	return rows

func ensure_view() -> void:
	if viewport:return
	viewport=SubViewport.new();viewport.name="WheelViewport";viewport.size=Vector2i(View.SIZE)
	viewport.transparent_bg=true;viewport.disable_3d=true;viewport.gui_disable_input=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	view=View.new();view.size=View.SIZE;view.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(view)
	var surface:=MeshInstance3D.new();surface.name="WheelSurface"
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*PANEL_SIZE;surface.mesh=quad
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=true;material.render_priority=110
	material.albedo_texture=viewport.get_texture();surface.material_override=material;add_child(surface)

func toggle(stick: Vector2) -> void:
	if input.opened:close();return
	if not rig.can_open_weapon_wheel():return
	tribes_shop=rig.game.match_mode.tribes.can_refit(rig.game.multiplayer.get_unique_id())
	if tribes_shop:tribes_inventory.open(rig.game.local_state())
	shopping=rig.game.match_mode.defusal.can_buy(rig.game.multiplayer.get_unique_id());page=0
	entries=inventory();input.open(entries.map(func(row):return row.id),stick)
	if not input.opened:return
	ensure_view();follow_hand();show();refresh_view();pulse(.18)

func close() -> void:
	input.close();hide()
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func reset() -> void:
	close();input.reset()

func update(stick: Vector2) -> void:
	if input.opened and tribes_shop and not rig.game.match_mode.tribes.can_refit(rig.game.multiplayer.get_unique_id()):reset();return
	if input.opened and shopping and not rig.game.match_mode.defusal.can_buy(rig.game.multiplayer.get_unique_id()):reset();return
	if input.opened and not rig.can_open_weapon_wheel():close()
	if input.opened:
		follow_hand()
		var next:=inventory()
		var slots: Array=next.map(func(row):return row.id)
		if slots!=input.slots:
			# Inventory/class changes must not select a different weapon under a held stick.
			input.close();input.open(slots,stick)
			if not input.opened:close()
		entries=next
	var previous: int=input.hover
	var selected: int=input.sample(stick)
	if selected>=0:
		if tribes_shop:
			var exit_shop: bool=tribes_inventory.select(selected,rig.game.match_mode.tribes,rig.game.multiplayer.get_unique_id())
			if exit_shop:tribes_shop=false
			entries=inventory();input.open(entries.map(func(row):return row.id),stick);refresh_view();return
		if shopping:
			if Shop.GROUPS.has(selected):page=selected
			elif selected==Shop.BACK:page=0
			else:rig.game.match_mode.defusal.send("buy",selected);pulse(.3)
			entries=inventory();input.open(entries.map(func(row):return row.id),stick);refresh_view();return
		if selected in [110,111,112]:
			rig.game.match_mode.defusal.send("grenade",[110,111,112].find(selected));pulse(.3);close();return
		if rig.game.match_mode.tribes.enabled() and selected in [9,10]:
			if rig.game.local_state().get("tribes_grenade",9)!=selected:rig.game.match_mode.tribes.cycle_grenade(1)
			pulse(.3);close();return
		if rig.can_open_weapon_wheel() and rig.game.local_state().get("owned",[]).has(selected):
			if rig.game.match_mode.defusal.utility.selected(rig.game.multiplayer.get_unique_id())>=0:rig.game.match_mode.defusal.send("grenade",-1)
			rig.game.desired_weapon=selected;pulse(.3)
		close()
	elif input.opened:
		if input.hover!=previous:pulse(.08)
		refresh_view()
	elif visible:close()

func refresh_view() -> void:
	if view and view.set_content(entries,input.hover,-1 if shopping or tribes_shop else int(rig.game.local_state().get("weapon",-1)),input.waiting_for_center):
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func pulse(strength: float) -> void:
	if not rig.simulated:rig.right.trigger_haptic_pulse("haptic",0,strength,.035,0)
