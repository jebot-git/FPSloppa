extends RefCounted
## Cold authored map metadata; copied once into the resident core.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Hydrology=preload("res://tools/voxel_battle/hydrology.gd")
static func terrain()->Dictionary:
 Landscape.prepare_roads()
 var pads:Array=[];var rivers:Array=[]
 for i in Landscape.CENTERS.size():pads.append({"center":Landscape.CENTERS[i],"radius":Landscape.RADII[i]})
 for river in Hydrology.RIVERS:
  for i in river.points.size()-1:rivers.append({"a":river.points[i],"b":river.points[i+1],"width":river.width*.5,"depth":river.depth})
 return {"extent":Landscape.EXTENT,"tile":Landscape.TILE,"port":Landscape.CENTERS[2],"main_bins":Landscape.road_bins,"access_bins":Landscape.access_bins,"pads":pads,"rivers":rivers}
