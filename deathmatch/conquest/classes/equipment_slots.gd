extends RefCounted
const PRIMARY=[[1,4,14],[9,10,16],[3,12,13],[5,11,15]]
const ROLES=["shocktroop","scout","medic","technician"]
static func equipped(game,id:int)->Array:
 if not game.classes.states.has(id) or not game.players.has(id):return []
 var role:int=maxi(0,ROLES.find(game.classes.role(id)));var owned:Array=game.players[id].get("owned",[])
 var primary:int=game.classes.equipment(id);var secondary:int=game.classes.equipment(id,true)
 if not owned.has(primary):
  for w in PRIMARY[role]:
   if owned.has(w):primary=w;break
 if not owned.has(secondary):
  for w in ([0,8] if role==1 else [0,2]):
   if owned.has(w):secondary=w;break
 return [primary,secondary]

static func mount(head:Transform3D,left_handed:bool,primary:bool)->Transform3D:
 var side:float=-1. if left_handed else 1.
 var yaw:=Basis(Vector3.UP,head.basis.get_euler().y)
 var at:=head.origin+yaw*(Vector3(side*.16,-.49,-.24) if primary else Vector3(side*.26,-.68,-.03))
 var carry:=Basis(Vector3.UP,side*deg_to_rad(72))*Basis(Vector3.FORWARD,side*deg_to_rad(15)) if primary else Basis(Vector3.RIGHT,deg_to_rad(-65))
 return Transform3D(yaw*carry,at)
