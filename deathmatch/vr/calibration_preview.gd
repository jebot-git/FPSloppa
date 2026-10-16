extends VBoxContainer
## A private local avatar stage; never alters the multiplayer avatar instance.
var game
var viewport:SubViewport
var preview:Node3D
var stage:Node3D
var selected:=""
var status:Label
var stock:Button
var confirmed:=false
var hands:Array=[]
var facing_yaw:=0.0
func setup(arena)->void:
 game=arena
 var image:=TextureRect.new();image.custom_minimum_size=Vector2(320,220);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.flip_h=true;add_child(image)
 viewport=SubViewport.new();viewport.size=Vector2i(640,560);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.audio_listener_enable_3d=false;add_child(viewport);image.texture=viewport.get_texture()
 stage=Node3D.new();viewport.add_child(stage)
 var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,.95,-2.9);camera.look_at(Vector3(0,.85,0));camera.fov=45;camera.make_current()
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
 var adjustments:=HBoxContainer.new();add_child(adjustments)
 var recenter:=Button.new();recenter.text="CALIBRATE / RECENTER";recenter.custom_minimum_size.y=52;recenter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;adjustments.add_child(recenter);recenter.pressed.connect(func():
  if game.is_vr():game.xr_rig.recenter()
  confirmed=false
  if game.loadout_menu:game.loadout_menu.calibration_confirmed=false;game.loadout_menu.refresh())
 stock=Button.new();stock.toggle_mode=true;stock.text="VIRTUAL STOCK: ON";stock.custom_minimum_size.y=52;stock.size_flags_horizontal=Control.SIZE_EXPAND_FILL;adjustments.add_child(stock);stock.pressed.connect(func():
  if game.is_vr():game.xr_rig.virtual_stock_enabled=not game.xr_rig.virtual_stock_enabled;game.xr_rig.save_turn_settings()
  else:
   var settings:=preload("res://deathmatch/vr/preferences.gd").read_settings();settings.virtual_stock=not settings.virtual_stock;preload("res://deathmatch/vr/preferences.gd").save_settings(settings)
  refresh_stock())
 refresh_stock()
 var confirm:=Button.new();confirm.text="CONFIRM AVATAR ALIGNMENT";confirm.custom_minimum_size.y=52;add_child(confirm);confirm.pressed.connect(func():
  if not is_instance_valid(preview):return
  confirmed=true
  if game.loadout_menu:game.loadout_menu.calibration_skin=selected;game.loadout_menu.calibration_confirmed=true;game.loadout_menu.refresh())
func _process(_delta:float)->void:
 var visible_now:bool=is_visible_in_tree() and game!=null and not game.headless
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible_now else SubViewport.UPDATE_DISABLED
 if not visible_now:return
 refresh_stock()
 var hash:String=game.avatars.library.selected
 if selected!=hash or not is_instance_valid(preview):
  if is_instance_valid(preview):preview.queue_free()
  preview=game.avatars.library.create_avatar(hash);selected=hash;confirmed=false
  if game.loadout_menu:game.loadout_menu.calibration_confirmed=false;game.loadout_menu.refresh()
  if preview:stage.add_child(preview);preview.preview_mode=0;preview.distance_ik_enabled=false
 if not is_instance_valid(preview):status.text="Select a local skin to preview.";return
 if game.is_vr():
  var pose:Dictionary=front_facing_pose(game.xr_rig.sample_pose())
  preview.target_xr_pose=pose;preview.left_handed=game.xr_rig.left_handed
  if hands.is_empty():
   for source in game.xr_rig.hand_models:
    var hand:Node3D=source.duplicate(Node.DUPLICATE_GROUPS|Node.DUPLICATE_SCRIPTS|Node.DUPLICATE_SIGNALS);stage.add_child(hand);hands.append(hand)
  for i in hands.size():
   hands[i].visible=pose.has("left" if i==0 else "right")
   if hands[i].visible:hands[i].transform=pose["left" if i==0 else "right"]
 status.text=("ALIGNMENT CONFIRMED" if confirmed else "Check head, controller reach and body scale. Your live tracked pose is mirrored here.")+"\nWorld scale: %.2f · Grip chest/hip weapons to draw; release to holster."%XRServer.world_scale

func refresh_stock()->void:
 var on:bool=game.xr_rig.virtual_stock_enabled if game.is_vr() else preload("res://deathmatch/vr/preferences.gd").read_settings().virtual_stock
 stock.set_pressed_no_signal(on);stock.text="VIRTUAL STOCK: "+("ON" if on else "OFF")

func front_facing_pose(source:Dictionary)->Dictionary:
 # Normalize only the private preview. Keep height, pitch, roll, reach and metadata;
 # every tracked transform uses the same rigid frame, including weapons and hands.
 var pose:=source.duplicate()
 if not source.get("head") is Transform3D:return pose
 facing_yaw=preload("res://deathmatch/vr/body_basis.gd").head_yaw(source,facing_yaw)
 var head:Transform3D=source.head
 var inverse:=Transform3D(Basis(Vector3.UP,facing_yaw),Vector3(head.origin.x,0,head.origin.z)).affine_inverse()
 for key in pose:
  if pose[key] is Transform3D:pose[key]=inverse*pose[key]
 return pose
