extends SceneTree
const Names=preload("res://deathmatch/ui/name_style.gd")
const Profile=preload("res://deathmatch/profile.gd")
const Processes=preload("res://deathmatch/launcher/process.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
func run() -> void:
 check(Names.plain(Names.display("^1Red^7Fox","^5VR"))=="[VR] RedFox","Clan and colour composition")
 check(Names.plain(Profile.clean("^1abcdefghijklmnopqrst"))=="abcdefghijklmnopqr","Colours do not consume visible limit")
 check(Profile.clean(" [VR]\nPilot ")=="VRPilot","Legacy name cleaning")
 check(Profile.clean("^1^2")=="Marine","Colour-only names receive a fallback")
 check(Names.plain(Profile.clean("a^^b^x"))=="a^b^x","Literal carets and unknown escapes")
 check(Names.clean(Names.display("^1Red^7Fox","^5VR"),Names.DISPLAY_LIMIT,"Marine",true)==Names.clean(Names.clean(Names.display("^1Red^7Fox","^5VR"),Names.DISPLAY_LIMIT,"Marine",true),Names.DISPLAY_LIMIT,"Marine",true),"Network normalization is idempotent")
 var unsafe:="[url=https://example.invalid]Click[/url]"
 var rich:=Names.rich_label();root.add_child(rich);Names.paint(rich,unsafe)
 check(rich.get_parsed_text()==unsafe and not rich.bbcode_enabled,"Name text cannot inject rich markup")
 check(Processes.endpoint("[::1]",7777).get("address")=="::1","Direct IPv6")
 check(Processes.endpoint("localhost",7777).get("address")=="localhost","Direct hostname")
 for address in ["https://example.com","bad host","127.0.0.1:7777",""]:check(Processes.endpoint(address,7777).has("error"),"Reject malformed direct address")
 for mode in [false,true]:
  var args:=Processes.arguments("res://deathmatch/arena.tscn",false,mode)
  check(args[args.find("--xr-mode")+1]==("on" if mode else "off"),"Explicit VR/desktop engine flag")
 var shell=load("res://deathmatch/launcher/launcher.tscn").instantiate();root.add_child(shell)
 var deadline:=Time.get_ticks_msec()+30000
 while shell.scanning_avatars and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
 check(not shell.scanning_avatars and shell.avatar_choice.item_count>1,"Validated installed avatar choices")
 shell.player_name.text="^1Red^7Fox";shell.clan_tag.text="^5VR";shell.avatar_choice.select(1);shell.preview_identity()
 check(shell.save_identity(),"Save identity")
 check(Profile.load_name()=="^1Red^7Fox" and Names.plain(Profile.load_clan())=="VR","Identity persists without doubling clan")
 var args: PackedStringArray=shell.game_arguments("::1",27960,true)
 check(args[args.find("--name")+1]=="^1Red^7Fox" and args[args.find("--clan")+1]=="^5VR^7","Launch passes separate name and clan")
 check(args[args.find("--avatar")+1]==shell.avatar_hash(),"Launch passes selected avatar hash")
 check(args[args.find("--connect")+1]=="::1" and args[args.find("--port")+1]=="27960" and args.has("--spectate"),"Direct match arguments preserve endpoint and role")
 if DisplayServer.get_name()!="headless":
  await create_timer(.3).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/launcher/identity-launcher.png")
 shell.free();rich.free()
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.spawn_points=[Vector3.ZERO];game.spawn_yaws=[0.0]
 game._add_player(1,Names.display("^1Red^7Fox","^5VR"))
 check(Names.plain(game.players[1].name)=="[VR] RedFox","Server player state preserves complete clan tag")
 if DisplayServer.get_name()!="headless":
  var actor=game.fighters[1];actor.set_nametag(game.players[1].name,0,Color.RED)
  check(actor.label.pieces.size()>=4,"3D tag emits coloured runs")
  check(actor.label.pieces[0].text=="◆ " and actor.label.pieces[0].modulate==Color.RED.lightened(.2),"Team symbol keeps team colour")
  check(actor.label.pieces.all(func(part):return not part.no_depth_test),"All coloured glyphs remain depth-tested")
  actor.show_alive(false,false);check(not actor.label.visible,"Death hides the entire coloured tag")
  actor.show_alive(true,false)
  var board=load("res://deathmatch/ui/scoreboard.gd").new();root.add_child(board);board.setup();board.refresh(game);board.show()
  check(board.rows[0].cells[1].get_parsed_text()=="[VR] RedFox","Scoreboard uses parsed coloured name")
  await create_timer(.25).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/launcher/identity-scoreboard.png")
  board.free();game.hud.hide()
  actor.position=Vector3.ZERO;actor.set_process(false);actor.set_physics_process(false)
  var camera: Camera3D=game.get_node("Overview");camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.position=Vector3(0,2,5);camera.look_at(Vector3(0,1.6,0));camera.make_current()
  actor.show_alive(true,false)
  await create_timer(.25).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/launcher/identity-nametag.png")
  camera.position=Vector3(4,2,4);camera.look_at(Vector3(0,1.6,0))
  await create_timer(.25).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/launcher/identity-nametag-angle.png")
 game.free()
 # Let the mixer release playback owned by the visual fixture before shutdown.
 await create_timer(.2).timeout
 print("IDENTITY_CHECK_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
