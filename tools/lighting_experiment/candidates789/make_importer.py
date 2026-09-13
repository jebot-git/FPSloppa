"""Generate instrumented test-only importer copies from the current sources."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'test-results/candidates789/importer';OUT.mkdir(exist_ok=True)
bake=(ROOT/'deathmatch/maps/baked_light.gd').read_text()
bake=bake.replace('var faces := 0','var layout: Array=[]\nvar scales:=PackedByteArray()\nvar faces := 0')
bake=bake.replace('func open(path: String) -> void:\n','func open(path: String) -> void:\n\tread_scales(path)\n')
bake=bake.replace('offset: int) -> PackedVector2Array:','offset: int,face_id: int=-1) -> PackedVector2Array:')
bake=bake.replace('\tvar lo:=Vector2(INF,INF);','\tvar spacing: float=float(1<<scales[face_id]) if face_id>=0 and face_id<scales.size() else 16.0\n\tvar lo:=Vector2(INF,INF);')
bake=bake.replace('/16.0','/spacing')
bake=bake.replace('\t# Replicated one-luxel gutters','\tlayout.append({"face":face_id,"rect":Rect2i(cursor,size+Vector2i(2,2)),"spacing":spacing})\n\t# Replicated one-luxel gutters')
bake=bake.replace('func finish(root: Node) -> void:\n','func finish(root: Node) -> void:\n\troot.set_meta("candidate_layout",layout)\n')
bake+='''
func read_scales(path: String) -> void:
 var f:=FileAccess.open(path,FileAccess.READ);f.seek(4);var end:=124
 for i in 15:
  var at:=f.get_32();var size:=f.get_32();end=maxi(end,at+size)
 f.seek((end+3)&~3)
 if f.get_position()+8>f.get_length() or f.get_buffer(4).get_string_from_ascii()!="BSPX":return
 var count:=f.get_32()
 for i in count:
  var name:=f.get_buffer(24).get_string_from_ascii();var at:=f.get_32();var size:=f.get_32()
  if name=="LMSHIFT":
   var saved:=f.get_position();f.seek(at);scales=f.get_buffer(size);f.seek(saved)
'''
(OUT/'baked_light.gd').write_text(bake.replace('\t',' '))
reader=(ROOT/'addons/bsp_importer/bsp_reader.gd').read_text().replace('class_name BSPReader','').replace('reader : BSPReader','reader').replace('var material_info := reader','var material_info = reader').replace('res://deathmatch/maps/baked_light.gd','res://test-results/candidates789/importer/baked_light.gd')
reader=reader.replace('Vector2(tex_width, tex_height), bsp_face.lightmap)','Vector2(tex_width, tex_height), bsp_face.lightmap, bsp_model.face_index+face_index)')
(OUT/'bsp_reader.gd').write_text(reader)
loader=(ROOT/'deathmatch/maps/loader.gd').read_text().replace('res://addons/bsp_importer/bsp_reader.gd','res://test-results/candidates789/importer/bsp_reader.gd')
(OUT/'loader.gd').write_text(loader)
print('Generated test-only importer in',OUT)
