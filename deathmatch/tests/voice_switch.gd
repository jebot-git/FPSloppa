extends SceneTree
var failures: Array=[]
class Capture extends Node:
 var events: Array
 func _exit_tree() -> void:events.append("closed")
class VoiceProbe extends "res://deathmatch/voice/chat.gd":
 var events: Array=[]
 func apply_input_device() -> void:
  events.append("device_closed" if not is_instance_valid(mic) else "device_LIVE")
 func start_capture() -> void:
  events.append("opened");mic=Capture.new();mic.events=events;add_child(mic)
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
 print("PASS " if value else "FAIL ",label)
 if not value:failures.append(label)
func run() -> void:
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var voice:=VoiceProbe.new();game.add_child(voice);voice.game=game
 game.headless=false;voice.start_capture();voice.events.clear()
 voice.select_input_device("Default")
 check(voice.events==["closed","device_closed","opened"],"Capture closes before device selection, then restarts once")
 var panel=load("res://deathmatch/voice/panel.gd").new();voice.add_child(panel);panel.setup(voice)
 var button: Button
 for child in panel.find_children("*","Button",true,false):
  if child.text.begins_with("Microphone:"):button=child
 voice.events.clear();button.pressed.emit()
 check(voice.events==["closed","device_closed","opened"],"Actual menu signal performs exactly one device transition")
 for i in 12:button.pressed.emit()
 check(voice.get_children().filter(func(n):return n is Capture).size()==1,"Repeated switches retain one attached capture node")
 voice.set_mode(0,true);voice.events.clear();voice.select_input_device("Default")
 check(voice.events==["device_closed"] and voice.mic==null,"Listen-only device switch never enables microphone")
 var saved=voice.Preferences.read_settings()
 check(saved.mode==0 and saved.input_device=="Default","Mode and selected device persist together")
 game.headless=true;voice.free();game.free();await process_frame;await process_frame
 print("VOICE_SWITCH_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
