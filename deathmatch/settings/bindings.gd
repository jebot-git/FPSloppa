extends RefCounted
const Profile=preload("res://deathmatch/profile.gd")
const KEYS={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"slow":KEY_SHIFT,"use":KEY_E,"melee":KEY_F,"scores":KEY_TAB,"chat":KEY_ENTER,"ptt":KEY_V,"down":KEY_CTRL,"fire":-MOUSE_BUTTON_LEFT,"offhand_fire":-MOUSE_BUTTON_RIGHT,"next_weapon":-MOUSE_BUTTON_WHEEL_UP,"previous_weapon":-MOUSE_BUTTON_WHEEL_DOWN}
const VR={"fire":"weapon:trigger","offhand_fire":"support:trigger","support":"support:grip","jump":"turn:ax_button","slow":"move:primary_click","use":"move:ax_button","scores":"move:by_button","menu":"turn:by_button","ptt":"support:grip"}
const INPUTS=["trigger","grip","ax_button","by_button","primary_click"]
var keys:=KEYS.duplicate()
var axes: Dictionary={"move":"move","turn":"turn"}
var vr:=VR.duplicate()
var two_handed:=true
var physical_jump:=false
var physical_crouch:=true
var face_expressions:=true
var physical_interactions:=true
func load_settings() -> void:
	var c:=ConfigFile.new();c.load(Profile.config_path())
	for action in KEYS:
		var value=c.get_value("bindings",action,KEYS[action])
		if value is int and value!=0 and value>=-9 and value<=KEY_SPECIAL+4096:keys[action]=value
	for action in axes:
		var value=c.get_value("vr_axes",action,action)
		if value in ["move","turn","left","right"]:axes[action]=value
	for action in VR:
		var value=c.get_value("vr_bindings",action,VR[action])
		if valid_vr(value):vr[action]=value
	for option in ["two_handed","physical_jump","physical_crouch","physical_interactions","face_expressions"]:
		var value=c.get_value("control_options",option,get(option))
		if value is bool:set(option,value)
func save() -> Error:
	var c:=ConfigFile.new();c.load(Profile.config_path())
	for action in keys:c.set_value("bindings",action,keys[action])
	for action in axes:c.set_value("vr_axes",action,axes[action])
	for action in vr:c.set_value("vr_bindings",action,vr[action])
	for option in ["two_handed","physical_jump","physical_crouch","physical_interactions","face_expressions"]:c.set_value("control_options",option,get(option))
	return c.save(Profile.config_path())
static func valid_vr(value: Variant) -> bool:
	if not value is String:return false
	var parts=value.split(":")
	return parts.size()==2 and parts[0] in ["weapon","support","move","turn","left","right"] and parts[1] in INPUTS
func pressed(action: String) -> bool:
	var code:int=keys.get(action,0)
	return Input.is_physical_key_pressed(code) if code>0 else Input.is_mouse_button_pressed(-code) if code<0 else false
func matches(action: String,event: InputEvent) -> bool:
	var code:int=keys.get(action,0)
	return (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==code) or (event is InputEventMouseButton and event.pressed and -event.button_index==code)
func controller(rig: Node,role: String) -> XRController3D:
	match role:
		"weapon":return rig.left if rig.left_handed else rig.right
		"support":return rig.right if rig.left_handed else rig.left
		"move":return rig.movement_hand()
		"turn":return rig.turning_hand()
		"left":return rig.left
		_:return rig.right
func vr_pressed(rig: Node,action: String) -> bool:
	var parts:String=vr.get(action,"")
	if not valid_vr(parts):return false
	var pieces:=parts.split(":");var hand:=controller(rig,pieces[0])
	if not rig.simulated and not hand.get_has_tracking_data():return false
	return hand.get_float(pieces[1])>.6 if pieces[1] in ["trigger","grip"] else hand.is_button_pressed(pieces[1])
func vr_event(rig: Node,action: String,hand: XRController3D,button: String) -> bool:
	var parts:String=vr.get(action,"");var pieces:=parts.split(":")
	return pieces.size()==2 and controller(rig,pieces[0])==hand and pieces[1]==button

func axis(rig: Node,action: String) -> Vector2:
	return controller(rig,axes.get(action,action)).get_vector2("primary")
