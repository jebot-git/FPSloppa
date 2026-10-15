extends RefCounted
## Deterministic authored bearing lanes, not a physics/load solver.
const STOREY:=3.6
const MIN_SUPPORT:=.45
const MIN_ADJACENT_SIDE:=.2
var buildings:Array=[]
var wall_building:Dictionary={}
var cell_building:Dictionary={}
func setup(layout,walls:Dictionary,cells:Array)->void:
 var authored:Array=layout.get("buildings",[]) if layout is Dictionary else layout.buildings
 for spec in authored:
  var row:Dictionary=spec.duplicate();row.walls=[];row.cells=[];row.stories=[];row.collision_rows=[]
  row.bounds=AABB(spec.center+Vector3(-spec.size.x*.5-.3,-.11,-spec.size.y*.5-.3),Vector3(spec.size.x+.6,spec.floors*STOREY+1.8,spec.size.y+.6))
  # Explicit ownership for authored rooftop additions outside the room shell.
  if spec.get("role","")=="canopy watchtower":row.bounds=AABB(spec.center+Vector3(-9.1,-.11,-11.1),Vector3(18.2,20.7,22.2))
  if spec.get("role","")=="observatory":row.bounds.size.y=17.
  row.attachments=[]
  for side in [-1,1]:
   var p:Vector3=spec.center+Vector3(0,3.1,side*(spec.size.y*.5+1.2))
   row.attachments.append(AABB(p-Vector3(.5,0,1.4),Vector3(1.,.7,2.8)))
  buildings.append(row)
 for index in walls:
  var wall:Dictionary=walls[index]
  for id in buildings.size():
   var building:Dictionary=buildings[id]
   if wall.kind!=building.kind or not building.bounds.has_point(wall.center):continue
   wall_building[index]=id;building.walls.append(index)
   for cell in wall.cells:building.cells.append(cell);cell_building[cell]=id
   break
 for index in layout.boxes.size():
  for building in buildings:
   if owns_row(building,layout.boxes[index]):building.collision_rows.append(index);break
 for building in buildings:
  for floor_index in int(building.floors):
   var columns:Array=[]
   var bottom:float=building.center.y+floor_index*STOREY+.1
   for id in building.cells:
    var cell:Dictionary=cells[id];var axis:int=walls[cell.wall].axis
    var normal_axis:int=2 if axis==0 else 0
    var half:float=building.size.y*.5 if normal_axis==2 else building.size.x*.5
    var local:Vector3=cell.center-building.center
    # Full-height front piers and the 1.9m side-window piers define bearing
    # lanes. Window apertures and door headers are never counted as columns.
    if absf(absf(local[normal_axis])-half)>.02:continue
    if cell.size.y<1.6 or cell.center.y-cell.size.y*.5<bottom-.02 or cell.center.y+cell.size.y*.5>bottom+3.52:continue
    var side:int=(0 if normal_axis==2 else 2)+(1 if local[normal_axis]>0 else 0)
    var critical:=PackedInt32Array()
    for other_id in building.cells:
     var other:Dictionary=cells[other_id]
     if walls[other.wall].axis!=axis or absf(other.center[normal_axis]-cell.center[normal_axis])>.02:continue
     if other.center.y+other.size.y*.5<=bottom+.01 or other.center.y-other.size.y*.5>=bottom+3.49:continue
     var overlap:float=minf(cell.center[axis]+cell.size[axis]*.5,other.center[axis]+other.size[axis]*.5)-maxf(cell.center[axis]-cell.size[axis]*.5,other.center[axis]-other.size[axis]*.5)
     if overlap>.01:critical.append(other_id)
    columns.append({"side":side,"weight":cell.size[axis],"cells":critical})
   building.stories.append(columns)
func status(id:int,broken:Dictionary)->Dictionary:
 var building:Dictionary=buildings[id];var lowest:=1.;var failed_floor:=-1
 var floor_values:Array=[]
 for floor_index in building.stories.size():
  var total:=0.;var intact:=0.;var side_total:=[0.,0.,0.,0.];var side_intact:=[0.,0.,0.,0.]
  for column in building.stories[floor_index]:
   var alive:bool=true
   for cell in column.cells:
    if broken.has(cell):alive=false;break
   total+=column.weight;side_total[column.side]+=column.weight
   if alive:intact+=column.weight;side_intact[column.side]+=column.weight
  var ratio:float=intact/total if total>0 else 1.
  var sides:Array=[]
  for side in 4:sides.append(side_intact[side]/side_total[side] if side_total[side]>0 else 1.)
  var failed:bool=ratio<MIN_SUPPORT
  for a in [0,1]:
   for b in [2,3]:
    if sides[a]<MIN_ADJACENT_SIDE and sides[b]<MIN_ADJACENT_SIDE:failed=true
  lowest=minf(lowest,ratio);floor_values.append({"remaining":ratio,"sides":sides,"failed":failed})
  if failed and failed_floor<0:failed_floor=floor_index
 return {"remaining":lowest,"failed_floor":failed_floor,"stories":floor_values}
func owns_row(building:Dictionary,row:Dictionary)->bool:
 if row.kind!=building.kind or not building.bounds.has_point(row.center):return false
 # Keep the ground-level floor slab; upper floors, walls and contents collapse.
 return row.center.y+row.size.y*.5>building.center.y+.2
static func contains_point(building:Dictionary,point:Vector3)->bool:
 if building.bounds.has_point(point):return true
 for bounds in building.attachments:
  if bounds.has_point(point):return true
 return false
static func contains_triangle(building:Dictionary,points:PackedVector3Array,indices:PackedInt32Array,offset:int)->bool:
 var upper:=false
 for j in 3:
  if points[indices[offset+j]].y>building.center.y+.2:upper=true
 if not upper:return false
 var regions:Array=[building.bounds];regions.append_array(building.attachments)
 for bounds in regions:
  var inside:=true
  for j in 3:
   if not bounds.has_point(points[indices[offset+j]]):inside=false;break
  if inside:return true
 return false
