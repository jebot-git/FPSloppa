extends RefCounted
## Exact point-hull intervals from converted BSPs. Profiles are bound to BSP bytes.
const MAX_VISITS=4096
const MAX_INTERVALS=256
const ROLES=["wood","metal","concrete","vent","glass","stop"]
const RESISTANCE={"wood":1.,"glass":1.,"vent":2.,"concrete":4.,"metal":1./.15,"stop":INF}
var planes: Array[Plane]=[]
var nodes: Array=[]
var leaves: Array=[]
var faces: Array=[]
var models: Array=[]
var plane_faces: Dictionary={}
var visits:=0
var exhausted:=false
static var index: Dictionary={}
static func v(a):return Vector3(a[0],a[1],a[2])
static func vector(a) -> bool:
 return a is Array and a.size()==3 and a.all(func(x):return (x is float or x is int) and is_finite(x) and absf(x)<100000)
func open(path: String,root: Node3D) -> bool:
 if index.is_empty():index=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/penetration/index.json"))
 var hash:=FileAccess.get_sha256(path)
 if not index.has(hash):return false
 var record: Dictionary=index[hash]
 if not str(record.path).begins_with("res://deathmatch/maps/penetration/") or FileAccess.get_sha256(record.path)!=record.sha256:return false
 var file:=FileAccess.open(record.path,FileAccess.READ)
 if not file or file.get_length()>16000000:return false
 var data=JSON.parse_string(file.get_as_text())
 if not data is Dictionary or data.get("source_sha256")!=hash:return false
 return configure(data,root)
func configure(data: Dictionary,root: Node3D) -> bool:
 planes.clear();nodes.clear();leaves.clear();faces.clear();models.clear();plane_faces.clear()
 if data.get("version")!=2:return false
 for key in ["planes","nodes","leaves","faces","models"]:
  if not data.get(key) is Array or data[key].is_empty() or data[key].size()>65536:return false
 for row in data.planes:
  if not row is Array or row.size()!=4 or not vector(row.slice(0,3)) or not (row[3] is float or row[3] is int) or not is_finite(row[3]) or absf(row[3])>100000:return false
  var n: Vector3=v(row)
  if absf(n.length_squared()-1)>.001:return false
  planes.append(Plane(n,row[3]))
 for value in data.leaves:
  if not (value is float or value is int) or value!=int(value) or value>=0 or value< -15:return false
 leaves=data.leaves
 for i in data.nodes.size():
  var row=data.nodes[i]
  if not row is Array or row.size()!=5 or not row.all(func(x):return (x is float or x is int) and is_finite(x) and x==int(x)):return false
  if row[0]<0 or row[0]>=planes.size() or row[3]<0 or row[4]<0 or row[3]+row[4]>data.faces.size():return false
  for child in row.slice(1,3):
   if child>=0 and (child<=i or child>=data.nodes.size()) or child<0 and -child-1>=leaves.size():return false
 nodes=data.nodes
 var points:=0
 for i in data.faces.size():
  var row=data.faces[i]
  if not row is Array or row.size()!=4 or not (row[0] is float or row[0] is int) or row[0]!=int(row[0]) or row[0]<0 or row[0]>=planes.size() or (row[1]!=0 and row[1]!=1) or row[2] not in ROLES:return false
  if not row[3] is Array or row[3].size()<3 or row[3].size()>4096 or not row[3].all(vector):return false
  points+=row[3].size()
  if points>1000000:return false
  var polygon:=PackedVector3Array()
  for point in row[3]:polygon.append(v(point))
  faces.append({"plane":int(row[0]),"side":int(row[1]),"material":row[2],"polygon":polygon})
  var key:=int(row[0])
  if not plane_faces.has(key):plane_faces[key]=[]
  plane_faces[key].append(i)
 var entities: Dictionary={}
 for node in root.find_children("*","CollisionObject3D",true,false):
  if node.get_script()!=preload("res://deathmatch/maps/entity.gd") or node.collision_layer&1==0:continue
  var key: String=str(node.attributes.get("model",""))
  if key.begins_with("*"):entities[key.substr(1).to_int()]=node
 if data.models.size()>4096:return false
 for row in data.models:
  if not row is Dictionary or not row.get("id") is float and not row.get("id") is int or not row.get("head") is float and not row.get("head") is int:return false
  if row.id!=int(row.id) or row.head!=int(row.head) or row.head<0 or row.head>=nodes.size():return false
  if not row.get("bounds") is Array or row.bounds.size()!=2 or not row.bounds.all(vector):return false
  if not row.get("faces") is Array or row.faces.size()!=2 or row.faces[0]<0 or row.faces[1]<0 or row.faces[0]+row.faces[1]>faces.size():return false
  if row.id!=0 and not entities.has(int(row.id)):continue
  var node: Node3D=root if row.id==0 else entities[int(row.id)]
  models.append({"id":int(row.id),"head":int(row.head),"node":node,"basis":node.global_basis,"faces":row.faces})
 return not models.is_empty() and models[0].id==0
func contains_point(face: Dictionary,point: Vector3) -> bool:
 var n: Vector3=planes[face.plane].normal;var sign_value:=0
 for i in face.polygon.size():
  var a: Vector3=face.polygon[i];var b: Vector3=face.polygon[(i+1)%face.polygon.size()]
  var side: float=(b-a).cross(point-a).dot(n)
  if absf(side)<.0001:continue
  var value:=1 if side>0 else -1
  if sign_value!=0 and value!=sign_value:return false
  sign_value=value
 return sign_value!=0
func surface(model: Dictionary,node: int,point: Vector3) -> String:
 if node<0:return "stop"
 var plane: int=nodes[node][0];var tested:=0
 for i in plane_faces.get(plane,[]):
  if i<model.faces[0] or i>=model.faces[0]+model.faces[1]:continue
  tested+=1
  if tested>512:exhausted=true;return "stop"
  if contains_point(faces[i],point):return faces[i].material
 return "stop"
func model_intervals(model: Dictionary,start: Vector3,direction: Vector3,limit: float) -> Array:
 var segments: Array=[];var stack: Array=[[model.head,0.,limit,-1,-1]]
 while not stack.is_empty():
  visits+=1
  if visits>MAX_VISITS:exhausted=true;return []
  var part: Array=stack.pop_back();var id:=int(part[0]);var lo: float=part[1];var hi: float=part[2]
  if hi-lo<.000001:continue
  if id<0:
   if int(leaves[-id-1])==-2:
    if not segments.is_empty() and lo<=segments[-1][1]+.00001:
     segments[-1][1]=hi;segments[-1][3]=part[4]
    else:segments.append([lo,hi,part[3],part[4]])
    if segments.size()>MAX_INTERVALS:exhausted=true;return []
   continue
  var row: Array=nodes[id];var plane: Plane=planes[int(row[0])]
  var distance:=plane.distance_to(start);var slope:=plane.normal.dot(direction)
  var a:=distance+slope*lo;var b:=distance+slope*hi
  if a>=0 and b>=0:stack.append([row[1],lo,hi,part[3],part[4]])
  elif a<=0 and b<=0:stack.append([row[2],lo,hi,part[3],part[4]])
  else:
   var split:=clampf(-distance/slope,lo,hi);var near_child: int=row[1] if a>0 else row[2];var far_child: int=row[2] if a>0 else row[1]
   stack.append([far_child,split,hi,id,part[4]]);stack.append([near_child,lo,split,part[3],id])
 var result: Array=[]
 for segment in segments:
  var material:=surface(model,segment[2],start+direction*segment[0])
  # A second visible material can only make the same solid more resistant.
  var exit_role:=surface(model,segment[3],start+direction*segment[1])
  if RESISTANCE[exit_role]>RESISTANCE[material] or exit_role=="glass" and material=="wood":material=exit_role
  result.append({"enter":segment[0],"leave":segment[1],"material":material})
 return result
func intervals(start: Vector3,direction: Vector3,limit: float) -> Array:
 visits=0;exhausted=false;var found: Array=[]
 for model in models:
  var node: Node3D=model.node
  if not is_instance_valid(node):return []
  if model.id!=0 and node.collision_layer&1==0:continue
  if not node.global_basis.is_equal_approx(model.basis):return [] # Translation only.
  found.append_array(model_intervals(model,start-node.global_position,direction,limit))
  if exhausted or found.size()>MAX_INTERVALS:return []
 found.sort_custom(func(a,b):return a.enter<b.enter)
 return found
