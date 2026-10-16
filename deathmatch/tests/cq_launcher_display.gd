extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Display=preload("res://deathmatch/vr/weapon_display.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var t1:=Models.weapon(5,"cq_technician");root.add_child(t1)
 check(not Models.metadata(5,"cq_technician").has("monitor_position") and not t1.has_node("GuidanceMonitor"),"T1 has neither monitor mount nor runtime readout")
 check(Models.metadata(5,"cq_technician").triangles==2930,"T1 frame and pedestal removed: 24 fewer triangles")
 var t2:=Models.weapon(11,"cq_technician");root.add_child(t2);t2.scale=Vector3.ONE*.65
 var panel=t2.get_node_or_null("GuidanceMonitor")
 check(panel!=null,"T2 creates its integrated guidance readout")
 if panel:
  check(panel.global_transform.is_equal_approx(Display.mount(t2)),"T2 readout follows the authored screen frame")
  check(panel.screen.mesh.size==Vector2(.046,.046),"Readout fits inside the square source monitor bezel")
  panel.update_guidance(t2,{"elapsed":.75},{},0.);check(panel.label.text=="ACQUIRING\n050%\nHOLD AIM","Partial lock renders acquisition progress")
  panel.update_guidance(t2,{"ready":true},{},0.);check(panel.label.text=="LOCKED\nHOMING READY","Ready lock renders homing information")
  panel.update_guidance(t2,{}, {"cycling":11,"cycle_at":3.},2.);check(panel.label.text=="SEARCH\nRECHARGING\n1.0 s","Internal reload shows its remaining time alongside search status")
  panel.update_guidance(t2,{}, {"clips":{11:0}},0.);check(panel.label.text=="SEARCH\nPACK EMPTY","Empty pack shows depleted ammunition status")
  panel.update_guidance(t2,{}, {},0.);check(panel.label.text=="SEARCH\nVEHICLE LOCK\n500 m","Search shows the actual lock range")
  var shots:Dictionary={10:{"owner":7,"weapon":11,"life":8.2,"extra":{"owner_life":3}},11:{"owner":8,"weapon":11,"life":9.},12:{"owner":7,"weapon":5,"life":9.},13:{"owner":7,"weapon":11,"life":10.,"extra":{"owner_life":2}}}
  check(is_equal_approx(Display.latest_flight(shots,7,3),8.2),"Only own current-life homing missiles are tracked")
  shots[14]={"owner":7,"weapon":11,"life":11.5,"extra":{"owner_life":3}}
  check(Display.latest_flight(shots,7,3)==11.5,"Newest missile selected when multiple missiles are in flight")
  shots[14].life-=.5
  panel.update_guidance(t2,{"ready":true},{"cycling":11,"cycle_at":3.},2.,true,Display.latest_flight(shots,7,3))
  check(panel.label.text=="LOCKED\nIN FLIGHT\n11.0 s LEFT","Live countdown retains lock information during internal reload")
  check(Display.guidance_text({"elapsed":.75},{},0.,8.2)=="ACQUIRING 050%\nIN FLIGHT\n8.2 s LEFT","Acquisition remains visible while a previous missile flies")
  shots[14].visual_age=.3
  check(is_equal_approx(Display.latest_flight(shots,7,3),10.7),"Client snapshot age advances countdown between authority updates")
  shots[14].visual_age=12.
  check(is_equal_approx(Display.latest_flight(shots,7,3),8.2),"Expired newest missile falls back to an older live missile")
  shots.erase(14);shots.erase(10)
  check(Display.latest_flight(shots,7,3)<0.,"Impact/removal clears the flight countdown")
  shots[15]={"owner":7,"weapon":11,"life":0.}
  check(Display.latest_flight(shots,7,3)<0.,"Expired missile cannot leave a stale flight timer")
  t2.position=Vector3(3,2,-1);t2.rotation=Vector3(.2,.8,-.1)
  check(panel.global_transform.is_equal_approx(Display.mount(t2)),"Tracking/recoil moves the readout with its screen without a stale world transform")
  var lighting=load("res://tools/voxel_battle/baked_lighting.gd")
  lighting.convert_node(t2);check(panel.screen.material_override is ShaderMaterial and panel.screen.material_override.shader.resource_path.ends_with("weapon_display.gdshader"),"Baked-light conversion preserves the emissive screen material")
  panel.update_display(t1,"NO",false,true);check(not panel.visible,"Display cannot attach itself to the T1 launcher")
 var frame:Dictionary={"players":{},"mode":{"scores":[0,0],"winner":-2,"time":4.,"lighting_time":.5,"zones":[],"remaining":100.,"intermission":0.},"projectiles":{30:{"owner":7,"life":3,"team":0,"weapon":11,"position":Vector3.ZERO,"velocity":Vector3.FORWARD*40.,"remaining":8.2,"stuck":false}}}
 var snapshot:Array=preload("res://deathmatch/native/cq_presentation.gd").project(frame,100.,1,120.)
 var row:Dictionary=snapshot[10].ordnance[30].duplicate();row.owner=snapshot[7][0][2];row.weapon=snapshot[7][0][3]
 check(row.extra.owner_life==3 and is_equal_approx(row.life,8.2),"Native presentation preserves owner generation separately from remaining seconds")
 check(is_equal_approx(Display.latest_flight({30:row},7,3),8.2),"Authority-projected missile drives the screen countdown")
 t1.free();t2.free();print("CQ_LAUNCHER_DISPLAY ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
