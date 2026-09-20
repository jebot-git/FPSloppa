extends Control
var client
var token:=""
var password: LineEdit
var message: Label
var districts: OptionButton
var players: OptionButton
var controls: VBoxContainer
var login_button: Button
var next_refresh:=0.0
var fetching:=false
func setup(owner_client) -> void:
	client=owner_client
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back:=ColorRect.new();back.color=Color(0,0,0,.78);back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(back)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(570,0);box.add_theme_constant_override("separation",12);center.add_child(box)
	var title:=Label.new();title.text="MODERATOR";title.add_theme_font_size_override("font_size",30);box.add_child(title)
	password=LineEdit.new();password.secret=true;password.placeholder_text="Master server moderator password";box.add_child(password)
	login_button=Button.new();login_button.text="Unlock moderator controls";login_button.pressed.connect(login);box.add_child(login_button);password.text_submitted.connect(func(_value):login())
	controls=VBoxContainer.new();controls.add_theme_constant_override("separation",10);box.add_child(controls);controls.hide()
	districts=OptionButton.new();districts.custom_minimum_size.x=570;controls.add_child(districts)
	button(controls,"Teleport to district",func():move("district"))
	players=OptionButton.new();players.custom_minimum_size.x=570;controls.add_child(players)
	button(controls,"Teleport to player",func():move("goto"))
	button(controls,"Bring player to me",func():move("bring"))
	var talk:=Button.new();talk.text="Hold to broadcast globally · F9";talk.button_down.connect(func():client.global_voice.talk(true));talk.button_up.connect(func():client.global_voice.talk(false));controls.add_child(talk)
	button(controls,"Lock moderator controls",lock_menu)
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=55;box.add_child(message)
	button(box,"Close · F8",toggle);hide()
func button(parent: Node,text: String,action: Callable) -> void:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=34;b.pressed.connect(action);parent.add_child(b)
func toggle() -> void:
	visible=not visible
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if not visible:
		password.clear();districts.get_popup().hide();players.get_popup().hide();client.global_voice.talk(false)
	elif token.is_empty():password.grab_focus()
	else:refresh()
func login() -> void:
	if login_button.disabled:return
	var value:=password.text;password.clear();login_button.disabled=true
	var reply: Dictionary=await client.request("moderator_login",{"password":value});value="";login_button.disabled=false
	if reply.has("error"):message.text=str(reply.error);return
	token=reply.result.moderator_token;controls.show();password.hide();login_button.hide();message.text="Unlocked for one hour. Teleports preserve district capacity.";refresh()
func lock_menu() -> void:
	client.global_voice.talk(false)
	if not token.is_empty():await client.request("moderator_logout",{"moderator_token":token})
	token="";controls.hide();password.show();login_button.show();message.text="Moderator controls locked."
func refresh() -> void:
	if fetching or token.is_empty():return
	fetching=true
	var reply: Dictionary=await client.request("moderator_list",{"moderator_token":token});fetching=false
	if reply.has("error"):
		message.text=str(reply.error)
		if "unauthorized" in str(reply.error) or "expired" in str(reply.error):token="";controls.hide();password.show();login_button.show();client.global_voice.talk(false)
		return
	var selected_d=districts.get_item_metadata(districts.selected) if districts.selected>=0 else null
	var selected_p=players.get_item_metadata(players.selected) if players.selected>=0 else null
	districts.clear();players.clear()
	for row in reply.result.districts:
		districts.add_item("%s · %s · %d/16%s"%[row.id,row.name,int(row.count),"" if row.online else " · offline"])
		var i:=districts.item_count-1;districts.set_item_metadata(i,row.id);districts.set_item_disabled(i,not row.online)
		if row.id==selected_d:districts.select(i)
	for row in reply.result.players:
		players.add_item("%s · #%d · %s"%[row.name,int(row.id),row.get("district") if row.get("district")!=null else "waiting"])
		var i:=players.item_count-1;players.set_item_metadata(i,int(row.id))
		if int(row.id)==selected_p:players.select(i)
	for row in reply.result.audit:
		if int(row.moderator)==int(client.actor.id) and row.action!="login":message.text="%s · player #%d · %s"%[row.action,int(row.player),row.result]
func move(action: String) -> void:
	var request:={"moderator_token":token,"action":action}
	if action=="district":
		if districts.selected<0:return
		request.district=districts.get_item_metadata(districts.selected)
	else:
		if players.selected<0:return
		request.player=players.get_item_metadata(players.selected)
	var reply: Dictionary=await client.request("moderator_move",request)
	message.text=str(reply.error) if reply.has("error") else "Teleport queued. Waiting for a safe arrival point."
func _process(delta: float) -> void:
	next_refresh-=delta
	if visible and next_refresh<=0 and not token.is_empty() and not client.busy:next_refresh=2;refresh()
