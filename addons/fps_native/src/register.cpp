#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include "codec.h"
#include "backend.h"
#include "authority.h"
#include "world_runtime.h"
#include "movement_runtime.h"
#include "destruction_runtime.h"
#ifndef FPS_SERVER
#include "poses.h"
#include "avatar_runtime.h"
#include "audio_runtime.h"
#endif
using namespace godot;
static void initialize(ModuleInitializationLevel level) {
 if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;
 GDREGISTER_CLASS(FPSCodec);
 GDREGISTER_CLASS(FPSBackend);
 GDREGISTER_CLASS(FPSAuthority);
 GDREGISTER_CLASS(FPSWorld);
 GDREGISTER_CLASS(FPSMovement);
 GDREGISTER_CLASS(FPSDestruction);
#ifndef FPS_SERVER
 GDREGISTER_CLASS(FPSPose);
 GDREGISTER_CLASS(FPSAvatar);
 GDREGISTER_CLASS(FPSAudio);
#endif
}
static void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT fpsloppa_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
 GDExtensionBinding::InitObject init(get_proc,library,initialization);
 init.register_initializer(initialize);init.register_terminator(terminate);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
