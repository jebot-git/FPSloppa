extends SceneTree
const Poses=preload("res://deathmatch/vr/poses.gd")
const Equipment=preload("res://deathmatch/avatars/equipment.gd")
class Resident extends RefCounted:
 var actions:Array=[]
 func request(kind:int,a:int=0,b:int=0,c:int=0):actions.append([kind,a,b,c])
class Patient extends Node3D:
 func render_position():return global_position
class Game extends Node:
 var classes=preload("res://deathmatch/conquest/classes/rules.gd").new()
 var desired_weapon:=4
 var clock:=0.
 var resident=Resident.new()
 var players:Dictionary={1:{"team":0,"dead":false},-1:{"team":0,"dead":false}}
 var fighters:Dictionary={}
class Rig extends Node3D:
 var game
 var origin:=Node3D.new()
 var head:=Node3D.new()
 var left:=XRController3D.new()
 var right:=XRController3D.new()
 var left_aim:=XRController3D.new()
 var right_aim:=XRController3D.new()
 var hand_models:Array=[Node3D.new(),Node3D.new()]
 var hand_animators:Array=[{"curls":[]},{"curls":[]}]
 var left_handed:=false
 var simulated:=true
 var cq_hands:Dictionary={"holding":false}
 var cq_utility
 var medic_interactions
 var shoulder_radio:Dictionary={"held":false,"held_hand":-1}
 func repair_cabin_passenger():return false
 func mounted_for_cq():return false
 func feedback(_strength:float,_seconds:float,_offhand:bool):pass
 func shoulder_mount(_radio:bool):return Transform3D(Basis.IDENTITY,Vector3(-.2,1.3,0))
 func sample_raw_pose():
  return {"head":head.transform,"left":left.transform,"right":right.transform,"weapon":right.transform,"offhand_weapon":left.transform,"left_handed":false}
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var game:=Game.new();root.add_child(game);game.classes.game=game;game.classes.ensure(1)["class"]="medic";game.classes.states[1].equipped_utility="medical"
 var rig:=Rig.new();game.add_child(rig);rig.game=game
 for n in [rig.origin,rig.head,rig.left,rig.right,rig.left_aim,rig.right_aim]+rig.hand_models:rig.add_child(n)
 rig.head.position=Vector3(0,1.65,0);rig.right.position=Vector3(.3,1,-.3)
 var left_tracker:=XRControllerTracker.new();left_tracker.name="/user/hand/left";XRServer.add_tracker(left_tracker);rig.left.tracker=left_tracker.name
 var right_tracker:=XRControllerTracker.new();right_tracker.name="/user/hand/right";XRServer.add_tracker(right_tracker);rig.right.tracker=right_tracker.name
 var utility=preload("res://deathmatch/vr/cq_utility.gd").new();utility.setup(rig);rig.cq_utility=utility
 rig.left.position=rig.shoulder_mount(false).origin;utility.update(.016,true)
 left_tracker.set_input("grip",1.);utility.update(.016,true)
 check(utility.held and utility.box_mode and game.desired_weapon==6,"physical shoulder grip takes medical box")
 left_tracker.set_input("trigger",1.);utility.update(.016,true)
 check(game.resident.actions.is_empty(),"box trigger does not deploy or heal")
 var c:Dictionary={"xr":rig.sample_raw_pose(),"input_blocked":false,"fire":true};utility.decorate(c)
 check(not c.fire and c.weapon==6,"held medical box suppresses firing")
 left_tracker.set_input("grip",0.);utility.update(.016,true)
 check(game.resident.actions==[[0,6,1,0]] and not utility.held,"releasing box sends one reliable physical-left-hand drop")
 utility.update(.016,true);check(game.resident.actions.size()==1,"released box cannot repeatedly deploy")
 game.classes.states[1].dispenser_ready=15.;utility.update_box(true)
 check(not utility.box_model.visible and not utility.box_available(),"deployed box is hidden during fifteen-second cooldown")
 game.clock=14.99;utility.update_box(true);check(not utility.box_model.visible,"box stays unavailable before cooldown ends")
 game.clock=15.;utility.hand_clock=1.;utility.update_box(true);check(utility.box_model.visible and utility.box_available(),"replacement returns at fifteen seconds")
 left_tracker.set_input("trigger",0.);rig.left.position=utility.tool_mount().origin;utility.update(.016,true)
 left_tracker.set_input("grip",1.);utility.update(.016,true)
 check(utility.held and not utility.box_mode and game.desired_weapon==7,"back-hip grip takes injector independently of box")
 left_tracker.set_input("trigger",1.)
 c={"xr":rig.sample_raw_pose(),"input_blocked":false};utility.decorate(c)
 check(c.fire and c.weapon==7 and c.xr.left_handed,"injector trigger uses held physical hand")
 check(c.xr.weapon.is_equal_approx(Equipment.injector_pose(rig.left.transform)),"injected native pose matches visible grip correction")
 var pen:Node3D=Equipment.utility("medical");rig.add_child(pen)
 check(is_equal_approx(pen.scale.x,1.15) and is_equal_approx(Equipment.injector_tip().length()*2,.21275),"injector has consistent twenty-one-centimetre scale")
 var patient:=Patient.new();game.add_child(patient);patient.position=Vector3(.1,0,-.5);game.fighters[-1]=patient;game.classes.downed[-1]={"remaining":10.};game.classes.injecting[-1]={"medic":1,"progress":.5}
 var interaction=preload("res://deathmatch/vr/medic_interactions.gd").new();interaction.setup(rig);rig.medic_interactions=interaction;interaction.update(true)
 check(interaction.injection_target==-1,"confirmed native revival attaches injector")
 var anchor:Vector3=interaction.injector_pose()*Equipment.injector_tip()
 rig.left.position+=Vector3(.2,.1,.1);interaction.update(true);interaction.attach_hand()
 check((interaction.injector_pose()*Equipment.injector_tip()).distance_to(anchor)<.00001,"injecting hand stays at contact while tracked controller drifts")
 var hand_model:Transform3D=rig.hand_models[0].global_transform*Equipment.injector_grip()
 check(hand_model.is_equal_approx(interaction.injector_pose()),"hand and needle remain attached to the same injection pose")
 left_tracker.set_input("trigger",0.);interaction.update(true);check(interaction.injection_target==0,"trigger release detaches injecting hand")
 utility.release();left_tracker.set_input("grip",0.);rig.right.position=interaction.chest(-1)+Vector3(0,0,-.75);right_tracker.set_input("grip",0.);interaction.update(true)
 right_tracker.set_input("grip",1.);interaction.update(true)
 check(interaction.drag_hand==1 and interaction.drag_target==-1,"free weapon hand can deliberately grab incapacitated ally")
 c={"xr":rig.sample_raw_pose(),"input_blocked":false,"fire":true,"melee":true};interaction.decorate(c)
 check(c.cq_drag and not c.fire and not Poses.validate(c.xr).is_empty(),"drag hand selection preserves validated physical poses without requiring a held gun")
 right_tracker.set_input("grip",0.);interaction.update(true);check(interaction.drag_hand==-1,"grip release stops drag gesture")
 XRServer.remove_tracker(left_tracker);XRServer.remove_tracker(right_tracker)
 utility.box_model=null;utility.rig=null;interaction.rig=null;rig.cq_utility=null;game.classes.game=null
 game.queue_free();await process_frame
 print("CQ_MEDIC_INTERACTIONS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
