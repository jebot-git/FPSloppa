#pragma once
#include "bot_names.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class FPSBots : public RefCounted {
 GDCLASS(FPSBots, RefCounted)
 Ref<PhysicsRayQueryParameters3D> ray;
 BotNames names;
protected: static void _bind_methods();
public:
 FPSBots();
 void st_route(Object *ai,int64_t id,Dictionary brain,bool recharging);
 void st_precision(Object *ai,int64_t id,Dictionary brain);
 void perceive(Object *ai,int64_t id,Dictionary brain);
 void combat(Object *ai,int64_t id,Dictionary brain,double delta);
 void steer(Object *ai,int64_t id,Dictionary brain,double delta);
};
}
