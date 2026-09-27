extends Node3D
const State=preload("res://deathmatch/vr/weapon_wheel_state.gd")
const View=preload("res://deathmatch/ui/weapon_wheel.gd")
const Shop=preload("res://deathmatch/counterstrike/buy_wheel.gd")
var input=State.new()
var rig_ref: WeakRef
var rig:
	get:return rig_ref.get_ref()
var viewport: SubViewport
var view: Control
var entries: Array=[]
var shopping:=false
var page:=0

func setup(owner_rig: Node) -> void:
	rig_ref=weakref(owner_rig);name="WeaponWheel";position=Vector3(0,-.025,-1.25);hide()

func inventory() -> Array:
	var game=rig.game;var state: Dictionary=game.local_state()
	if shopping:return Shop.rows(game.match_mode.defusal,game.multiplayer.get_unique_id(),page)
	var owned: Array=state.get("owned",[]).duplicate();owned.sort()
	var rows: Array=[]
	for id in owned:
		if not game.armory.valid(id) or rows.any(func(row):return row.id==id):continue
		var data: Dictionary=game.match_mode.fortress.weapon_data(game.multiplayer.get_unique_id(),id)
		var ammo: int=-1 if data.ammo<0 else state.get("ammo",[0,0,0,0])[data.ammo]
		rows.append({"id":id,"name":data.name,"ammo":ammo,"usable":ammo<0 or ammo>=data.cost})
	rows.append_array(game.match_mode.defusal.utility.inventory(game.multiplayer.get_unique_id()))
	return rows

func ensure_view() -> void:
	if viewport:return
	viewport=SubViewport.new();viewport.name="WheelViewport";viewport.size=Vector2i(View.SIZE)
	viewport.transparent_bg=true;viewport.disable_3d=true;viewport.gui_disable_input=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	view=View.new();view.size=View.SIZE;view.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(view)
	var surface:=MeshInstance3D.new();surface.name="WheelSurface"
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*1.05;surface.mesh=quad
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=true;material.render_priority=110
	material.albedo_texture=viewport.get_texture();surface.material_override=material;add_child(surface)

func toggle(stick: Vector2) -> void:
	if input.opened:close();return
	if not rig.can_open_weapon_wheel():return
	shopping=rig.game.match_mode.defusal.can_buy(rig.game.multiplayer.get_unique_id());page=0
	entries=inventory();input.open(entries.map(func(row):return row.id),stick)
	if not input.opened:return
	ensure_view();show();refresh_view();pulse(.18)

func close() -> void:
	input.close();hide()
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func reset() -> void:
	close();input.reset()

func update(stick: Vector2) -> void:
	if input.opened and shopping and not rig.game.match_mode.defusal.can_buy(rig.game.multiplayer.get_unique_id()):reset();return
	if input.opened and not rig.can_open_weapon_wheel():close()
	if input.opened:
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
		if shopping:
			if Shop.GROUPS.has(selected):page=selected
			elif selected==Shop.BACK:page=0
			else:rig.game.match_mode.defusal.send("buy",selected);pulse(.3)
			entries=inventory();input.open(entries.map(func(row):return row.id),stick);refresh_view();return
		if selected in [110,111,112]:
			rig.game.match_mode.defusal.send("grenade",[110,111,112].find(selected));pulse(.3);close();return
		if rig.can_open_weapon_wheel() and rig.game.local_state().get("owned",[]).has(selected):
			if rig.game.match_mode.defusal.utility.selected(rig.game.multiplayer.get_unique_id())>=0:rig.game.match_mode.defusal.send("grenade",-1)
			rig.game.desired_weapon=selected;pulse(.3)
		close()
	elif input.opened:
		if input.hover!=previous:pulse(.08)
		refresh_view()
	elif visible:close()

func refresh_view() -> void:
	if view and view.set_content(entries,input.hover,-1 if shopping else int(rig.game.local_state().get("weapon",-1)),input.waiting_for_center):
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func pulse(strength: float) -> void:
	if not rig.simulated:rig.right.trigger_haptic_pulse("haptic",0,strength,.035,0)
