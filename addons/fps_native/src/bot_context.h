#pragma once
#include "bot_names.h"
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <algorithm>
#include <cmath>
namespace godot {
namespace bot {
inline double n(const Dictionary &d,const Variant &key){return d[key];}
inline bool b(const Dictionary &d,const Variant &key){return d[key];}
inline Vector3 v(const Dictionary &d,const Variant &key){return d[key];}
inline String s(const Dictionary &d,const Variant &key){return d[key];}
inline bool one_of(const String &s,std::initializer_list<const char *> values){for(auto value:values)if(s==value)return true;return false;}
// Only lives for one call. Reuse the query object, never actor/world snapshots
// across ticks, respawns or level changes. All calls run on the scene thread.
struct Context {
 const BotNames &k;
 Object *ai,*mode,*fortress,*navigation,*teamplay,*tribes,*titanball,*defusal,*armory;
 Node3D *game;
 Dictionary players,fighters;
 String kind;
 double clock;
 Ref<PhysicsRayQueryParameters3D> query;
 Context(Object *owner,const Ref<PhysicsRayQueryParameters3D> &ray,const BotNames &names):k(names),ai(owner),query(ray){
  game=Object::cast_to<Node3D>(ai->get(k.game.name));players=game->get(k.players.name);fighters=game->get(k.fighters.name);mode=game->get(k.match_mode.name);fortress=mode->get(k.fortress.name);defusal=mode->get(k.defusal.name);
  navigation=ai->get(k.navigation.name);teamplay=ai->get(k.teamplay.name);tribes=ai->get(k.tribes.name);titanball=ai->get(k.titanball.name);armory=game->get(k.armory.name);kind=mode->get(k.kind.name);clock=game->get(k.clock.name);
 }
 Node3D *actor(int64_t id){return Object::cast_to<Node3D>(fighters[id]);}
 bool alive(int64_t id){if(!players.has(id)||!fighters.has(id))return false;Dictionary p=players[id];return !b(p,k.dead.value)&&!b(p,k.spectator.value);}
 Vector3 eye(int64_t id){Node3D *a=actor(id);return a->get_position()+Vector3(0,1,0)*double(a->call(k.eye_height.name));}
 Vector3 target(int64_t id){Node3D *a=actor(id);return a->get_position()+Vector3(0,1,0)*double(a->call(k.torso_height.name));}
 Dictionary ray(Vector3 start,Vector3 end){query->set_from(start);query->set_to(end);return game->get_world_3d()->get_direct_space_state()->intersect_ray(query);}
};
}
}
