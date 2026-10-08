extends SceneTree
## Local demonstration: ten bots plus one spectator, one six-round-cap match.
var game
var role: String
var joined: Dictionary={}
func _initialize():run.call_deferred()
func run():
 role="server" if OS.get_cmdline_user_args().has("--server") else "client"
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 if role=="server":
  game.bot_population.count_target=10;game.bot_population.maintain()
  # Keep the first buy phase ready until the spectator has finished joining.
  game.set_physics_process(false)
  while game.players.values().all(func(s):return not s.spectator):
   game._send_snapshot();await create_timer(.1).timeout
  game.set_physics_process(true)
 else:
  root.title="FPSloppa · Dust2 · 5v5 bots · Six-round cap"
 while is_instance_valid(game):
  if game.active and game.current_map=="de_varq_dust2":
   var teams: Array=[0,0];var spectators:=0;var shots:=0;var kills:=0
   for id in game.players:
    var s: Dictionary=game.players[id]
    if s.spectator:spectators+=1
    elif s.team in [0,1]:teams[s.team]+=1
    shots+=int(s.get("shots",0));kills+=int(s.get("kills",0))
   var de=game.match_mode.defusal
   if role=="server" and de.phase=="finished":game.intermission=3600.
   var pen=game.get_node("Map/MapRuntime").ballistics
   var report={"pid":OS.get_process_id(),"role":role,"map":game.current_map,"bsp_sha256":game.map_sha,"teams":teams,"spectators":spectators,"round":de.round_id,"phase":de.phase,"scores":game.match_mode.scores,"win_limit":de.win_limit,"round_cap":2*(de.win_limit-1),"bsp_penetration_ready":pen.bsp_cover!=null and not pen.bsp_cover.models.is_empty(),"shots":shots,"kills":kills}
   if role=="client":report.local_spectator=game.local_state().get("spectator",false)
   FileAccess.open("res://test-results/de-spectated/"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
   if role=="client" and not joined.has("capture") and spectators==1 and teams==[5,5]:
    joined.capture=true
    await create_timer(2).timeout;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://test-results/de-spectated/spectator.png")
  await create_timer(1).timeout
