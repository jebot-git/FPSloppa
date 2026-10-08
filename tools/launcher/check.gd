extends SceneTree
const Lists=preload("res://deathmatch/launcher/playlists.gd")
const Catalog=preload("res://deathmatch/audio/music/catalog.gd")
var failures: Array=[]
func check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var args:=OS.get_cmdline_user_args();var base:=args[args.find("--asset-root")+1]
 var music:=base.path_join("bgm")
 var source:=ProjectSettings.globalize_path("res://deathmatch/audio/music/dead_air.ogg")
 var other:=ProjectSettings.globalize_path("res://deathmatch/audio/music/please_hold.ogg")
 check(Lists.stem("map","../../escape",false).is_empty(),"Reject unsafe map names")
 check(Lists.stem("mode","invalid",false).is_empty(),"Reject unknown modes")
 for options in [["global","",false],["mode","dm",false],["map","qsrc_dm1",false],["map","qsrc_dm1",true]]:
  var result:=Lists.save(music,options[0],options[1],options[2],[other,source])
  check(not result.has("error"),"Playlist save: "+str(result))
 var catalog:=Catalog.new();catalog.scan(music,["qsrc_dm1"])
 for options in [["dm","qsrc_dm1",true,"win:map:qsrc_dm1"],["dm","qsrc_dm1",false,"map:qsrc_dm1"],["dm","other",false,"mode:dm"],["ctf","other",false,"global"]]:
  var result: Dictionary=catalog.choose(options[0],options[1],options[2])
  check(result.key==options[3],"Game selects playlist scope "+options[3])
  check(result.tracks.size()==2,"Exactly two tracks per scope; hidden copies not scanned")
  if result.tracks.size()==2:
   check(FileAccess.get_sha256(result.tracks[0])==FileAccess.get_sha256(other),"Actual game preserves user track order")
   check(FileAccess.get_sha256(result.tracks[1])==FileAccess.get_sha256(source),"Actual game preserves second track")
 var replaced:=Lists.save(music,"mode","dm",false,[source])
 check(not replaced.has("error"),"Replace owned playlist")
 catalog.scan(music,["qsrc_dm1"])
 check(catalog.choose("dm","other").tracks.size()==1,"Old copies do not leak into updated playlist")
 Lists.write_text(music.path_join("ctf_launcher.m3u8"),"# User-owned playlist\n")
 check(Lists.save(music,"mode","ctf",false,[source]).has("error"),"Preserve unowned playlists")
 check(Lists.save(music,"mode","tf",false,[source],Callable(),func():return true).get("error")=="Cancelled.","Cancelled playlist is not published")
 check(not FileAccess.file_exists(music.path_join("tf_launcher.m3u8")),"Cancelled save preserves disk state")
 var shell=load("res://deathmatch/launcher/launcher.tscn").instantiate();root.add_child(shell)
 await process_frame
 shell.start_job({"action":"playlist","scope":"mode","target":"st","climax":false,"tracks":[source],"titles":["Original track title"]})
 var deadline:=Time.get_ticks_msec()+30000
 while shell.job_pid>0 and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
 check(shell.job_pid<0 and shell.progress.value==100,"Window spawns worker and receives success/progress")
 check(Lists.read_index(music).get("st_launcher",{}).get("tracks",[{}])[0].get("title")=="Original track title","Saved track titles survive edits")
 shell.directory.cancel()
 var key: String=shell.directory.add_favorite("127.0.0.1",28777,28779)
 check(not key.is_empty(),"Save favourite")
 var reload=load("res://deathmatch/ui/server_directory.gd").new();root.add_child(reload)
 check(reload.favorites.has(key),"Favourites reload through game's directory")
 reload.free()
 shell.directory.rows[key].merge({"name":"Local integration server","online":true,"ping_ms":4,"humans":3,"bots":5,"open_slots":5,"capacity":8,"spectators":0,"reserved":0,"mode":"dm","map":"qsrc_dm1","map_title":"Place of Two Deaths","weapon_rules":"quake","state":"match","version":"0.22v","protocol":shell.protocol},true)
 shell.selected=key;shell.render_servers()
 check(not shell.join_button.disabled,"Bot-filled server remains joinable")
 shell.directory.rows[key].open_slots=0;shell.render_servers();check(shell.join_button.disabled,"Full server blocked")
 shell.directory.rows[key].open_slots=5;shell.directory.rows[key].protocol="wrong";shell.render_servers();check(shell.join_button.disabled,"Protocol mismatch blocked")
 shell.directory.rows[key].protocol=shell.protocol;shell.render_servers()
 if args.has("--visual"):
  shell.tracks.assign([source,other]);shell.track_titles.assign(["Dead Air.ogg","Please Hold.ogg"]);shell.render_tracks()
  for i in 3:
   shell.tabs.current_tab=i
   await create_timer(.25).timeout
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/launcher/tab-%d.png"%i)
  root.size=Vector2i(960,760)
  for i in 3:
   shell.tabs.current_tab=i
   await create_timer(.25).timeout
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/launcher/small-%d.png"%i)
 print("LAUNCHER_CHECK_RESULT ",JSON.stringify(failures));shell.free();quit(0 if failures.is_empty() else 1)
