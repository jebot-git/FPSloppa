extends SceneTree
const Reload=preload("res://deathmatch/conquest/classes/reload_state.gd")
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for capacity in [3]:
		for left_handed in [false,true]:
			var pose:Dictionary={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.7,0)),"weapon":Transform3D(Basis.IDENTITY,Vector3(0,1.3,0)),"left":Transform3D.IDENTITY,"right":Transform3D.IDENTITY,"offhand_weapon":Transform3D.IDENTITY,"left_handed":left_handed}
			var side:String="right" if left_handed else "left"
			var p:=Reload.make(0);p.mag=false
			var total:int=capacity*2;var clip:=0
			var pouch:Vector3=Reload.pouch(pose).origin;var socket:Vector3=Reload.model_pose(pose,12)*Reload.MAG_POINTS[12]
			pose[side]=Transform3D(Basis.IDENTITY,pouch)
			clip=Reload.sample(p,12,clip,total,capacity,pose,false,false,0.0)
			clip=Reload.sample(p,12,clip,total,capacity,pose,true,false,.05)
			check(p.grab=="ammo","%d-charge pack: fresh %s support grip draws from pouch"%[capacity,side])
			pose[side].origin=pouch+Vector3.UP*.14
			clip=Reload.sample(p,12,clip,total,capacity,pose,true,false,.15)
			check(p.left_pouch and clip==0 and not p.ready,"%d-charge pack needs a real pouch draw before seating"%capacity)
			pose[side].origin=pose[side].origin.lerp(socket,.45)
			clip=Reload.sample(p,12,clip,total,capacity,pose,true,false,.25)
			pose[side].origin=socket
			clip=Reload.sample(p,12,clip,total,capacity,pose,true,false,.35)
			check(clip==capacity and p.mag and p.ready and not p.locked and p.stroke==0 and Reload.can_fire(p,12),"%d-charge pack arms on side insertion without cocking"%capacity)
			check(not Reload.rack_contact(12,p,Reload.model_pose(pose,12),Reload.model_pose(pose,12)*Reload.RACK_POINTS[12]),"Ordnance geometry cannot grab an invisible charging handle")
			Reload.eject_mag(p);check(not p.ready and not Reload.can_fire(p,12),"Removed pack immediately disables launcher")
			var stale:=Reload.make(0);stale.mag=false;stale.grab="ammo";stale.left_pouch=true;stale.started=0.0
			clip=Reload.sample(stale,12,0,total,capacity,{},true,false,1.0)
			check(clip==0 and not stale.ready,"Missing tracked pose cannot seat or arm a pack")
	print("CQ_LAUNCHER_RELOAD_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
