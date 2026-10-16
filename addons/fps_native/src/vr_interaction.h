#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
namespace godot {
// One instance per local aim/stock interaction. Scene/controller ownership stays
// with the rig; the engagement hysteresis and smoothing state live here.
class FPSVRInteraction : public RefCounted {
 GDCLASS(FPSVRInteraction,RefCounted)
 bool engaged=false;
 int last_weapon=-1;
 double blend=0;
 Basis alignment;
 bool sampled=false;
 Vector3 previous[2],thrust;
 double travel[2]={0,0},strength=0;
protected: static void _bind_methods();
public:
 bool get_engaged() const{return engaged;} void set_engaged(bool v){engaged=v;}
 int get_last_weapon() const{return last_weapon;} void set_last_weapon(int v){last_weapon=v;}
 double get_blend() const{return blend;} void set_blend(double v){blend=v;}
 Basis get_alignment() const{return alignment;} void set_alignment(Basis v){alignment=v;}
 Vector3 swim(Transform3D head,Vector3 left,Vector3 right,double dt,bool allowed);
 void swim_reset();
 double get_strength() const{return strength;}
 Vector3 get_thrust() const{return thrust;}
 void advance(double delta);
 void reset();
 static bool supports(int weapon,const String &rules,bool stock);
 Transform3D aim(Transform3D primary,Transform3D support,int weapon,bool holding,bool valid,const String &rules,bool smooth,Vector3 anchor);
 Transform3D stock(Transform3D primary,Transform3D support,Transform3D head,int weapon,bool left_handed,bool valid,const String &rules,bool smooth);
 static Vector3 launch(Vector3 velocity);
 static Vector3 guided(Transform3D weapon,Vector3 velocity);
 static PackedVector3Array arc(PhysicsDirectSpaceState3D *space,Vector3 start,Vector3 velocity,double duration,double gravity);
};
}
