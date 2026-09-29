extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Drop ammo",0,100,60,true,"de","cs16")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	var cs=g.variant_combat.cs;var de=g.match_mode.defusal
	for w in range(1,12):
		var d: Dictionary=g.armory.data(w)
		for loaded in [0,1,int(d.magazine)-1,int(d.magazine)]:
			g.dropped_weapons.clear();de.phase="live";g.intermission=0
			var s: Dictionary=g.players[-1];s.owned=[0,w];s.starting_weapons=[0];s.weapon=w;s.ammo=[240,64,300,40];s.hp=100;s.dead=false;s.spectator=false;s.invulnerable=0
			cs.state(-1).clips[w]=loaded
			g._damage(-1,-1,10000,"TEST",true)
			check(g.dropped_weapons.entries.size()==1 and g.dropped_weapons.entries.values()[0].amount==loaded,"DE death drops only loaded rounds: "+str([w,loaded]))
			var key: int=g.dropped_weapons.entries.keys()[0];var pickup: Dictionary=g.dropped_weapons.entries[key]
			var receiver: Dictionary=g.players[1];receiver.dead=false;receiver.spectator=false;receiver.owned=[0];receiver.weapon=0;receiver.ammo=[0,0,0,0]
			cs.cancel(1);g.fighters[1].position=pickup.position;g._collect(1,key)
			check(receiver.ammo[d.ammo]==loaded and cs.state(1).clips[w]==loaded,"DE pickup transfers the exact magazine without donor reserves")
	g.dropped_weapons.clear();var s: Dictionary=g.players[1];s.owned=[0,6];s.weapon=6;s.ammo=[0,0,150,0];s.dead=false;cs.cancel(1);cs.state(1).clips[6]=7
	de.replace_weapon(1,7)
	check(g.dropped_weapons.entries.values()[0].amount==7 and s.ammo[2]==143,"DE replacement drops loaded rounds and retains the owner's reserve")
	g.dropped_weapons.clear();s.owned=[0,6];s.starting_weapons=[0];s.weapon=6;s.ammo[2]=150;cs.state(1).clips[6]=1
	var physical: Dictionary=cs.physical(1);physical.mag=false;physical.carry=cs.Reload.REMOVED_MAG;physical.carried_rounds=22
	g.dropped_weapons.drop(1)
	check(g.dropped_weapons.entries.values()[0].amount==1,"Removed magazine and pouch ammo do not enter a DE drop")
	for rules in g.armory.IDS:
		g.match_mode.kind="dm";g.armory.select(rules)
		for w in g.armory.table.size():
			g.dropped_weapons.clear();s.owned=[w];s.starting_weapons=[];s.weapon=w;s.ammo=[0,0,0,0];s.spectator=false
			g.dropped_weapons.drop(1)
			var amount: int=g.dropped_weapons.entries.values()[0].amount
			var d: Dictionary=g.armory.data(w)
			var expected: int=0 if d.ammo<0 else int(d.magazine) if rules=="cs16" else {1:25,3:20,4:10,5:100,6:6,7:60,8:10,9:8,10:15}.get(w,1) if rules=="ut99" else [20,8,2,40][d.ammo]
			check(amount==expected,"Non-DE empty weapon gets its standard pickup ammo: "+str([rules,w]))
	g.disconnect_game();g.free();print("DROPPED_AMMO_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
