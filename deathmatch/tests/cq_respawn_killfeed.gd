extends SceneTree
const Menu=preload("res://deathmatch/ui/cq/menu.gd")
var checks:=0
class Squads extends RefCounted:
	var opened:=0
	var state:Dictionary={}
	func local()->Dictionary:return state
	func open_map()->void:opened+=1
class Lobby extends RefCounted:
	func active()->bool:return false
class Game extends RefCounted:
	var squads:=Squads.new()
	var demos:Dictionary={"playing":false}
	var intermission:=0.
	var lobby:=Lobby.new()
	var menu_open:=true
	var state:Dictionary={"dead":false,"spectator":false}
	var suicides:=0
	func local_state()->Dictionary:return state
	func request_suicide()->void:suicides+=1
	func is_vr()->bool:return false
class Hud extends RefCounted:
	var game:=Game.new()
	var suicide:=Button.new()
	var shown:=true
	func show_menu(value:bool)->void:shown=value
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:push_error(message);quit(1)
func _initialize()->void:run.call_deferred()
func run()->void:
	var hud:=Hud.new()
	Menu.refresh_respawn(hud,hud.game.state)
	check(hud.suicide.text=="SUICIDE" and not hud.suicide.disabled,"alive button offers suicide")
	Menu.activate_respawn(hud)
	check(hud.game.suicides==1 and not hud.shown and not hud.game.menu_open,"alive click requests suicide and closes menu")
	hud.game.state.dead=true
	Menu.refresh_respawn(hud,hud.game.state)
	check(hud.suicide.text=="RESPAWN" and not hud.suicide.disabled,"dead button offers respawn")
	Menu.activate_respawn(hud)
	check(hud.game.squads.opened==1 and hud.game.suicides==1,"dead click opens deployment without another suicide")
	hud.game.intermission=1
	Menu.activate_respawn(hud)
	check(hud.suicide.disabled and hud.game.squads.opened==1,"round completion blocks action")
	hud.game.intermission=0;hud.game.state={"dead":false,"spectator":true};hud.game.squads.state={"staging":true}
	Menu.refresh_respawn(hud,hud.game.state)
	check(hud.suicide.text=="RESPAWN" and not hud.suicide.disabled,"staging spectator can reach deployment")
	hud.game.squads.state={};Menu.activate_respawn(hud)
	check(hud.suicide.disabled and hud.game.suicides==1,"real spectator cannot suicide")
	var status=preload("res://deathmatch/vr/status_hud.gd").new();root.add_child(status);status.configure_cq()
	var entries:Array=[{"text":"Expired","until":1.},{"text":"Alpha → Bravo · Pistol","until":8.},{"text":"Bravo → Charlie · Carbine","until":8.},{"text":"Charlie → Delta · SMG","until":9.},{"text":"Delta → Alpha · Rifle","until":10.}]
	status.update_killfeed(entries,2.)
	check(status.kill_messages.size()==3 and status.kill_messages[0]==entries[2].text,"killfeed retains newest three unexpired entries")
	check(status.kill_labels[2].text==entries[4].text,"newest kill is beside status notifications")
	status.update_chat([{"text":"Squad message","until":12.}],2.)
	check(status.chat_labels[1].text=="Squad message" and status.chat_labels[0].position.y>=status.KILLFEED_HEIGHT,"chat remains separate from killfeed")
	status.update_killfeed(entries,9.)
	check(status.kill_messages.size()==1 and status.kill_labels[0].text.is_empty() and status.kill_labels[2].text==entries[4].text,"individual expiry clears old labels")
	status.update_killfeed(entries,10.)
	check(status.kill_messages.is_empty() and status.kill_labels.all(func(line):return line.text.is_empty()),"killfeed clears at expiry")
	check(status.VIEW_SIZE.y==292+status.KILLFEED_HEIGHT+status.CHAT_HEIGHT+status.NOTIFY_HEIGHT,"status surface reserves space for all rows")
	hud.suicide.free();status.queue_free()
	print("CQ_RESPAWN_KILLFEED_OK ",checks);quit()
