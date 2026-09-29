#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include "projectiles.h"
#include "codec.h"
#include "bots.h"
#ifndef FPS_SERVER
#include "poses.h"
#endif
using namespace godot;
static void initialize(ModuleInitializationLevel level) {
 if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;
 GDREGISTER_CLASS(FPSProjectiles);
 GDREGISTER_CLASS(FPSCodec);
 GDREGISTER_CLASS(FPSBots);
#ifndef FPS_SERVER
 GDREGISTER_CLASS(FPSPose);
#endif
}
static void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT fpsloppa_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
 GDExtensionBinding::InitObject init(get_proc,library,initialization);
 init.register_initializer(initialize);init.register_terminator(terminate);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
