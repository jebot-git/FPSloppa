extends SceneTree
const Config=preload("res://deathmatch/server/config.gd")
const Maps=preload("res://deathmatch/maps/loader.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Equipment=preload("res://deathmatch/tribes/equipment.gd")
var g
var checks:=0
var failures: Array=[]
var sequence:=100
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func request(kind: String,pose: Dictionary,velocity:=Vector3.ZERO) -> bool:
	sequence+=1
	return g.match_mode.fortress.physical.request_for(1,g.map_epoch,g.players[1].serial,sequence,kind,pose,velocity)
func place(point: Vector3):g.fighters[1].position=point;g.fighters[1].travel_path=[];g.fighters[1].velocity=Vector3.ZERO
func run():
	var config:=Config.parse('set sv_gametype "ST"\nset sv_weapon_rules "doom"\nset sv_gametypes "dm st"\nset sv_ballot_exclude_modes "st"')
	check(not config.has("error") and config.values.sv_weapon_rules=="tribes" and config.values.map=="ctf_stonehenge" and config.values.mode_maps.st==["ctf_stonehenge","ctf_raindance"],"Server configuration forces ST arsenal and dedicated default map")
	check(config.values.gametypes==["dm","st"] and config.values.ballot_exclude_modes==["st"],"ST supports normal votes and independent ballot exclusions")
	check(preload("res://deathmatch/server/discovery_protocol.gd").MODES.has("st"),"Discovery accepts ST")
	check(preload("res://deathmatch/maps/import_policy.gd").modes("st_new.bsp")==["st"],"Imported ST maps keep dedicated mode classification")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST rules",0,2,30,true,"st","doom");g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	await physics_frame;await physics_frame
	var mode=g.match_mode;var rules=mode.tribes;var s: Dictionary=g.players[1];var actor=g.fighters[1];var pads=rules.stations()
	check(g.active and mode.kind=="st" and g.current_map=="ctf_stonehenge" and g.armory.effective()=="tribes" and actor.tribes_enabled,"ST practice selects Stonehenge and forces Tribes movement/loadout")
	g.armory.select("cs16");check(g.armory.effective()=="tribes","ST cannot switch to a non-Tribes loadout")
	check(mode.team_game() and mode.limit()==2 and not g.jetpacks.enabled(),"ST uses capture limit, two teams and intrinsic jets")
	check(g.maps_for_mode("st")==["ctf_stonehenge","ctf_raindance"] and not "ctf_stonehenge" in g.maps_for_mode("ctf"),"Stonehenge is dedicated to ST")
	check(Maps.choices_for_mode(g.map_catalog,"st",["qsrc_dm1"]).is_empty() and not g._load_map("qsrc_dm1"),"Configured lists and direct map loads cannot bypass ST compatibility")
	var downloaded: Dictionary=preload("res://deathmatch/network/asset_jobs.gd").map_file("res://maps/ctf_stonehenge.bsp",g.map_sha,g.map_title,"/tmp/fps-st-download-%d/"%OS.get_process_id(),g.map_network.source_name())
	check(not downloaded.has("error") and Maps.available_for_mode(downloaded,"st") and Maps.supports_tribes(downloaded.path),"Downloaded Stonehenge preserves ST classification and required entities")
	check(s.owned==[0,2,3,9,10,11] and s.tribes_pack=="none" and s.tribes_class=="light" and s.weapon==3,"Classic Light spawn kit selects disc without free backpack")
	s.team=0;s.invulnerable=0
	place(mode.bases[1]);mode.tick(.016)
	check(mode.flags[1].carrier==1,"Enemy flag picks up by touch")
	place(mode.bases[0]);mode.flags[0].dropped=true;mode.flags[0].position=mode.bases[0]+Vector3.RIGHT*10;mode.flags[0].return_at=g.clock+20;mode.tick(.016)
	check(mode.scores[0]==0 and mode.flags[1].carrier==1,"Capture requires own flag at home")
	mode.return_flag(0);var score: int=s.kills;mode.tick(.016)
	check(mode.scores[0]==1 and s.kills==score+5 and mode.flags[1].carrier==0,"Capture scores for team and grants five personal points")
	place(mode.bases[1]);mode.tick(.016);place(Vector3(0,210,0));actor.velocity=Vector3(45,3,0);mode.drop(1)
	check(mode.flags[1].dropped and mode.flags[1].position.y>209 and is_equal_approx(mode.flags[1].return_at-g.clock,47.5),"Airborne death keeps flag in flight with 45-second timer and 2.5-second return interval")
	var start: Vector3=mode.flags[1].position;mode.st.tick(.1)
	check(mode.flags[1].position.x>start.x+4 and mode.flags[1].position.y>200,"Flag inherits carrier skiing momentum")
	check(not mode.st.can_take(1,1),"Dropped flag has a short thrower pickup grace period")
	g.clock+=.61;check(mode.st.can_take(1,1),"Dropper can recover flag after grace")
	place(mode.bases[0]+Vector3.RIGHT*20);g.clock=mode.flags[1].return_at;mode.tick(.016)
	check(not mode.flags[1].dropped and mode.flags[1].position==mode.bases[1],"Expired airborne flag returns home")
	mode.flags[0].dropped=true;mode.flags[0].position=actor.position;mode.flags[0].return_at=g.clock+20;mode.tick(.016)
	check(not mode.flags[0].dropped,"Touching friendly dropped flag returns it")
	# Physical item requests use production RPC epoch/life/sequence and pose guards.
	s.physical=true;s.input_blocked=false;s.yaw=0;place(g.ctf_spawns[0][0]);s.hp=40
	for left in [false,true]:
		s.tribes_kit=true;s.hp=40;rules.combat.cancel(1)
		var pose:=Poses.neutral();pose.left_handed=left
		pose.weapon=pose.left if left else pose.right
		var hand: String="right" if left else "left"
		pose[hand]=Equipment.mount(pose,"kit")
		check(not Poses.validate(pose).is_empty() and Equipment.target(pose,s,false)=="kit","Hip kit reachable with handedness %s"%left)
		check(request("hold_kit",pose) and request("activate",pose) and s.hp==70 and not s.tribes_kit,"Hip kit grip then trigger heals once: %s"%left)
		check(not request("activate",pose),"Holding trigger cannot reuse consumed kit: %s"%left)
		request("cancel",pose)
		pose.body={"hips":Transform3D(Basis(Vector3.UP,.6),Vector3(.1,.95,.05))};pose.head.origin=Vector3(.25,1.5,-.18);s.tribes_kit=true
		pose[hand]=Equipment.mount(pose,"kit")
		check(Equipment.target(pose,s,false)=="kit","Hip kit follows tracked pelvis during leaning: %s"%left)
		pose[hand]=Equipment.mount(pose,"pack");s.tribes_pack="shield";actor.tribes_state.pack="shield";actor.tribes_state.energy=60
		check(Equipment.target(pose,s,false)=="pack" and request("hold_pack",pose) and request("activate",pose) and actor.tribes_state.pack_on,"Chest trigger toggles active pack: %s"%left)
		request("cancel",pose);actor.tribes_state.pack_on=false;g.clock+=1
		mode.flags[1].carrier=1
		pose[hand]=Equipment.mount(pose,"flag")
		check(request("hold_flag",pose) and request("throw",pose,Vector3(0,1,-4)) and mode.flags[1].dropped,"Chest flag grip and swing releases physical pass: %s"%left)
		mode.return_flag(1)
	var neutral:=Poses.neutral();neutral.left.origin=Vector3(-.4,1.5,-.7);s.tribes_kit=true
	check(not request("hold_kit",neutral) and not request("activate",neutral),"Out-of-reach grabs and activation without a held item are rejected")
	s.dead=true;neutral.left=Equipment.mount(neutral,"kit");check(not request("hold_kit",neutral),"Dead player cannot use hip equipment");s.dead=false
	check(not g.match_mode.fortress.physical.request_for(1,g.map_epoch-1,s.serial,sequence+1,"hold_kit",neutral,Vector3.ZERO),"Previous-map physical request rejected")
	check(not g.match_mode.fortress.physical.request_for(1,g.map_epoch,s.serial-1,sequence+1,"hold_kit",neutral,Vector3.ZERO),"Previous-life physical request rejected")
	# Fixed base power, actual BSP traces, repair pack and stations.
	check(pads.generators.size()==2,"Both Stonehenge bases have generator interaction volumes")
	for row in pads.generators:
		var team: int=row.team;var at: Transform3D=row.frame
		var hit: Dictionary=g._trace(at*Vector3(0,0,4),at.origin,1)
		check(hit.get("generator",-1)==team,"Gun trace reaches generator housing %d"%team)
		s.team=1-team;g._damage_map_hit(hit,1,500)
		check(not pads.powered(team),"Enemy shots disable base %d power"%team)
		s.team=team;place(pads.rows.filter(func(r):return r.team==team)[0].position)
		check(not rules.can_refit(1) and not rules.select_equipment(1,"light",[0,2,3],"repair",true),"Offline station denies purchase %d"%team)
		rules.combat.beam(1,8,at*Vector3(0,0,4),-at.basis.z,1)
		check(pads.health[team]>0 and not pads.powered(team),"Initial repair beam heals generator but leaves power disabled %d"%team)
		for frame in 100:rules.combat.beam(1,8,at*Vector3(0,0,4),-at.basis.z,1)
		check(pads.powered(team) and rules.can_refit(1),"Sustained repair beam restores friendly base power %d"%team)
		var before: float=pads.health[team];pads.damage(team,1,100)
		check(pads.health[team]==before,"Friendly fire policy protects own generator %d"%team)
		pads.health[team]=300.0;s.team=1-team
		pads.blast(at*Vector3(0,0,4),1,1000,8)
		check(not pads.powered(team),"Visible explosive splash damages generator %d"%team)
		pads.health[team]=300.0
	g.clock+=1;s.team=0;rules.infinite_energy=true;rules.energy[0]=0
	check(rules.balance(1)==rules.MAX_TEAM_ENERGY,"Classic unlimited team energy option permits supply at zero reserve")
	rules.spend(1,3000);check(rules.energy[0]==0,"Unlimited purchases do not alter finite reserve")
	var snapshot: Dictionary=rules.snapshot();check(rules.valid_snapshot(snapshot),"ST base power and economy snapshot validates")
	var bad:=snapshot.duplicate(true);bad.generators[0]=NAN;check(not rules.valid_snapshot(bad),"Non-finite generator state rejected by replay validator")
	bad=snapshot.duplicate(true);bad.infinite_energy=1;check(not rules.valid_snapshot(bad),"Malformed economy policy rejected")
	var board:=preload("res://deathmatch/modes/scoreboard_data.gd").capture(g)
	check(board.st and board.tf and board.ranked[0].class_name=="LIGHT","Scoreboard exposes Tribes armour and score")
	mode.kind="ctf";g.armory.select("tribes");mode.flags[1].carrier=1;place(mode.bases[0]);mode.drop(1)
	check(not mode.flags[1].dropped or is_equal_approx(mode.flags[1].return_at-g.clock,30),"Ordinary CTF retains its original drop policy")
	mode.kind="st";s.team=0;mode.scores=[1,0];mode.return_flag(0);mode.flags[1].carrier=1;mode.flags[1].dropped=false;place(mode.bases[0]);mode.tick(.016)
	check(g.intermission>0 and mode.scores[0]==2 and g.round_message.contains("RED WINS"),"ST capture limit ends the match with the correct team winner")
	var result:={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/st-tribes/rules.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ST_TRIBES ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
