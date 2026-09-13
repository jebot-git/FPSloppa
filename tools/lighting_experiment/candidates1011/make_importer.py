"""Generate an isolated direction-atlas importer; never edit production scripts."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'test-results/candidates1011/importer';OUT.mkdir(exist_ok=True)
bake=(ROOT/'deathmatch/maps/baked_light.gd').read_text().replace('var lighting := PackedByteArray()','var lighting := PackedByteArray()\nvar directional_pixels:=PackedByteArray()')
bake=bake.replace('\tenabled=true','\tdirectional_pixels=FileAccess.get_file_as_bytes(path.get_basename()+".rgba")\n\tassert(directional_pixels.size()==lighting.size()*4)\n\tenabled=true').replace('Image.FORMAT_RGB8','Image.FORMAT_RGBA8')
start=bake.index('\t\t\tvar c:=Color8(lighting');end=bake.index('\n\t\t\timage.set_pixel',start)
bake=bake[:start]+'\t\t\tvar c:=Color8(directional_pixels[at*4],directional_pixels[at*4+1],directional_pixels[at*4+2],directional_pixels[at*4+3])'+bake[end:]
(OUT/'baked_light.gd').write_text(bake)
reader=(ROOT/'addons/bsp_importer/bsp_reader.gd').read_text().replace('class_name BSPReader','').replace('reader : BSPReader','reader').replace('var material_info := reader','var material_info = reader').replace('res://deathmatch/maps/baked_light.gd','res://test-results/candidates1011/importer/baked_light.gd')
(OUT/'bsp_reader.gd').write_text(reader)
(OUT/'loader.gd').write_text((ROOT/'deathmatch/maps/loader.gd').read_text().replace('res://addons/bsp_importer/bsp_reader.gd','res://test-results/candidates1011/importer/bsp_reader.gd'))
