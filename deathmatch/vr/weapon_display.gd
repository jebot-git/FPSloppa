extends Node3D
## A cached texture on the authored monitor glass, scaled with the weapon model.
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const GLASS_SIZE:=Vector2(1.82,1.2)*.035
var viewport:SubViewport
var label:Label
var screen:MeshInstance3D
var last_text:=""
func setup()->void:
 name="MassacreChargePanel"
 viewport=SubViewport.new();viewport.size=Vector2i(320,200);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
 var background:=ColorRect.new();background.color=Color("07181c");background.size=viewport.size;viewport.add_child(background)
 label=Label.new();label.position=Vector2(8,6);label.size=Vector2(304,188);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_override("font",preload("res://deathmatch/ui/cq/theme.gd").FONT);label.add_theme_font_size_override("font_size",27);viewport.add_child(label)
 screen=MeshInstance3D.new();screen.layers=1<<18;screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var quad:=QuadMesh.new();quad.size=GLASS_SIZE;screen.mesh=quad
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=viewport.get_texture();material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;screen.material_override=material;add_child(screen)
static func mount(model:Node3D)->Transform3D:
 return model.global_transform*Transform3D(Basis.IDENTITY,Models.anchor(5,"monitor_position"))
func update_display(model:Node3D,text:String,charging:bool,show_panel:bool)->void:
 visible=show_panel
 if not show_panel:return
 # Parent to the actual gun so tracking and recoil later in the frame cannot
 # leave the text one frame behind the glass.
 if get_parent()!=model:reparent(model,false)
 transform=Transform3D(Basis.IDENTITY,Models.anchor(5,"monitor_position"))
 var dimensions:Array=Models.metadata(5,"cq_technician").get("monitor_size",[GLASS_SIZE.x,GLASS_SIZE.y]);screen.mesh.size=Vector2(dimensions[0],dimensions[1])
 var formatted:=text.replace(" · ","\n").strip_edges()
 var signature:=formatted+str(charging)
 if signature==last_text:return
 last_text=signature;label.text=formatted;label.add_theme_color_override("font_color",Color("ffbe73") if charging else Color("73e5df"));viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
