extends SceneTree
const Cover=preload("res://deathmatch/counterstrike/bsp_penetration.gd")
const Pen=preload("res://deathmatch/counterstrike/penetration.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var anchor:=Node3D.new();root.add_child(anchor)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/de-restoration/bsp-cover.json"))
 var cover:=Cover.new();check(cover.configure(data,anchor),"Valid independently compiled BSP fixture")
 var pen:=Pen.new();pen.bsp_cover=cover;pen.ready=true;pen.map_root=anchor
 var hit:=pen.exit_surface(Vector3(0,1,0),Vector3.RIGHT,39./32)
 check(not hit.is_empty() and absf(hit.thickness-.25)<.0001 and hit.retention==.6,"Thin wood measures .25 m and retains 60 percent damage")
 var angle:=Vector3(1,0,.5).normalized();hit=pen.exit_surface(Vector3(0,1,0),angle,39./32)
 check(not hit.is_empty() and absf(hit.thickness-.25/angle.x)<.0001,"Oblique incidence charges actual increased thickness")
 check(pen.exit_surface(Vector3(0,1,5),Vector3.RIGHT,45./32).is_empty(),"Thick solid cannot become a forward-step wallbang")
 check(pen.exit_surface(Vector3(0,1,25),Vector3.RIGHT,45./32).is_empty(),"Unknown surface fails closed")
 hit=pen.exit_surface(Vector3(0,1,30),Vector3.RIGHT,39./32)
 check(not hit.is_empty() and absf(hit.thickness-.25)<.0001,"Touching solid partitions merge without artificial air gaps")
 check(cover.intervals(Vector3(-.002,1,35),Vector3.RIGHT,1.4).size()==2,"Real air gaps retain separate obstacles")
 check(pen.exit_surface(Vector3(0,1,40),Vector3.RIGHT,45./32).is_empty(),"Adjacent metal charges stronger resistance")
 anchor.position=Vector3(3,0,0)
 check(not pen.exit_surface(Vector3(3,1,0),Vector3.RIGHT,39./32).is_empty(),"Translated solid follows the live node")
 check(pen.exit_surface(Vector3(0,1,0),Vector3.RIGHT,39./32).is_empty(),"Translated solid leaves no phantom resistance")
 anchor.rotation.y=.2
 check(pen.exit_surface(Vector3(3,1,0),Vector3.RIGHT,39./32).is_empty(),"Unsupported rotation fails closed")
 anchor.transform=Transform3D.IDENTITY
 var bad:=data.duplicate(true);bad.nodes[0][1]=0
 check(not Cover.new().configure(bad,anchor),"Cyclic point hull rejected before traversal")
 bad=data.duplicate(true);bad.nodes[0][1]=999999
 check(not Cover.new().configure(bad,anchor),"Out-of-range child rejected")
 bad=data.duplicate(true);bad.faces[0][2]="not-a-material"
 check(not Cover.new().configure(bad,anchor),"Unknown material metadata rejected")
 bad=data.duplicate(true);bad.planes[0][0]=INF
 check(not Cover.new().configure(bad,anchor),"Non-finite plane rejected")
 check(not Cover.new().open("res://test-results/de-restoration/bsp-cover.bsp",anchor),"Unregistered BSP hash cannot borrow another map profile")
 bad=data.duplicate(true);bad.nodes=[]
 for i in 4100:bad.nodes.append([0,i+1 if i<4099 else -1,-1,0,0])
 bad.models=[data.models[0].duplicate(true)];bad.models[0].head=0
 var bounded:=Cover.new();check(bounded.configure(bad,anchor),"Deep acyclic fixture stays within load bounds")
 var normal: Vector3=bounded.planes[0].normal;var origin:=normal*(bounded.planes[0].d+10)
 check(bounded.intervals(origin,normal,1).is_empty() and bounded.exhausted,"Excessive query work blocks safely")
 var result:={"checks":checks,"failures":failures};FileAccess.open("res://tools/de_penetration/edge_cases.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("BSP_COVER_EDGE_CASES ",JSON.stringify(result));anchor.free();quit(0 if failures.is_empty() else 1)
