"""Re-export existing authored actions without rebaking or changing poses."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent/'animated'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'BA2-10m-walk.blend'),load_ui=False,use_scripts=False)
for o in bpy.context.scene.objects:o.select_set(o.name in ['BA2_10m','Bot.Armature','Bot.Mesh'])
bpy.ops.export_scene.gltf(filepath=str(OUT/'BA2-10m-walk.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,export_force_sampling=False,export_frame_range=False,export_anim_slide_to_zero=True,export_yup=True)
print('BA2_WALK_EXPORT_COMPLETE',flush=True)
