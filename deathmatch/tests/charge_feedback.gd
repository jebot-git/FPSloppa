extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Aim=preload("res://deathmatch/vr/aim_support.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Charge feedback",0,100,60,true,"dm","ut99")
 game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
 var s:Dictionary=game.players[1];s.weapon=6;s.ammo=[100,100,100,100];s.dead=false;s.spectator=false
 var command:Dictionary={"weapon":6,"fire":true,"alt_fire":false}
 var combat=game.variant_combat
 combat.update_charge_feedback(1,command)
 check(combat.charge_label(1).begins_with("CHARGE 0%"),"Local charge feedback starts before authority")
 game.clock+=.55;combat.update_charge_feedback(1,command)
 check(combat.local_charge.stage==1,"Rocket loading advances at half-second intervals")
 command.input_blocked=true;combat.update_charge_feedback(1,command)
 check(combat.local_charge.is_empty(),"Menu cancels charge feedback")
 command.input_blocked=false;combat.update_charge_feedback(1,command);combat.charge_fired(1,6)
 check(combat.local_charge.is_empty() and combat.charge_ready_at>game.clock,"Accepted release clears charge and respects refire interval")
 check(Aim.supports(2,"quake") and not Aim.supports(2,"doom"),"Support capability distinguishes shotgun from pistol at the same slot")
 var solver:=Aim.new();var primary:=Transform3D.IDENTITY
 var support:=Transform3D(Basis.IDENTITY,Vector3(.03,0,-.32))
 var first:=solver.solve(primary,support,2,true,true,"quake",true)
 solver.advance(.04);var blended:=solver.solve(primary,support,2,true,true,"quake",true)
 check(first.basis.is_equal_approx(primary.basis) and not blended.basis.is_equal_approx(primary.basis) and blended.origin==primary.origin,"Support blends orientation without changing the muzzle origin")
 var stock:=preload("res://deathmatch/vr/virtual_stock.gd").new()
 var head:=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0))
 primary.origin=Vector3(.18,1.3,-.15);support.origin=primary.origin+Vector3(.02,0,-.32)
 stock.solve(primary,support,head,2,false,true,"quake",true);stock.advance(.04)
 var braced:=stock.solve(primary,support,head,2,false,true,"quake",true)
 check(stock.engaged and braced.origin==primary.origin,"Quake shotgun can use an optional shoulder stock without muzzle translation")
 check(stock.solve(primary,support,head,2,false,false,"quake",true)==primary and not stock.engaged,"Tracking loss disengages virtual stock immediately")
 game.disconnect_game();game.free();await process_frame
 print("CHARGE_FEEDBACK_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
