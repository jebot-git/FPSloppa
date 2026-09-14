extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.start_host("Preparation clock",0,100,10,true,"tb","quake");g.set_process(false);g.set_physics_process(false)
 var clock=preload("res://deathmatch/audio/round_clock.gd").new();clock.game=g
 var ticks:Array=[];clock.ticked.connect(func(second):ticks.append(second))
 var tb=g.match_mode.titanball
 for frame in 600:
  g.round_left-=tb.advance_time(.1);clock._process(.1)
 check(ticks==[10,9,8,7,6,5,4,3,2,1],"Preparation plays the normal final-ten-second countdown once each")
 check(is_equal_approx(g.round_left,600.),"Preparation countdown leaves the ten-minute match timer untouched")
 g.round_left-=tb.advance_time(.1);clock._process(.1)
 check(not tb.preparing() and g.round_left<600.,"Gate release starts the match timer")
 g.round_left=10.;clock._process(.1);g.round_left=10.1;clock._process(.1);g.round_left=9.9;clock._process(.1)
 check(ticks.count(10)==2,"Match countdown re-arms independently and does not repeat after correction")
 tb.reset();g.players[1].dead=false;g.players[1].spectator=false
 var status=preload("res://deathmatch/ui/player_status.gd").read(g,1)
 check(status.carrier=="HANGAR OPENS IN 1:00","Player HUD exposes the preparation countdown")
 g.intermission=5;clock._process(.1);check(clock.played.is_empty(),"Intermission remains silent")
 print("TB_PREPARATION_CLOCK_RESULT ",JSON.stringify(failures))
 clock.free();g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
