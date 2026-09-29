#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/physics_shape_query_parameters3d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <unordered_map>
#include <vector>
namespace godot {
class FPSProjectiles : public RefCounted {
 GDCLASS(FPSProjectiles, RefCounted)
 struct Part { Transform3D inverse; Vector3 center,half; Transform3D pose; };
 std::vector<std::vector<Part>> bodies;
 std::unordered_map<uint64_t,std::vector<int>> cells;
 std::vector<int> overflow;
 Array ids;
 Ref<PhysicsRayQueryParameters3D> ray;
 Ref<PhysicsShapeQueryParameters3D> shape_query;
 Ref<SphereShape3D> sphere;
 static uint64_t key(int x,int z);
 static bool safe(Vector3 p);
 static bool large(int x,int z,int xx,int zz);
protected: static void _bind_methods();
public:
 FPSProjectiles();
 void configure_bodies(const Array &rows);
 void build(const Dictionary &players,const Dictionary &fighters,const Dictionary &movement);
 Array candidates(Vector3 start,Vector3 end,double radius);
 static double box_fraction(Vector3 start,Vector3 end,Vector3 half,double radius);
 double player_fraction(Vector3 start,Vector3 end,double height,double yaw,double radius);
 Dictionary trace(Node3D *game,Vector3 start,Vector3 end,int64_t exclude,double radius,const Dictionary &movement,const Variant &candidate_ids,const Dictionary &historical=Dictionary());
 void step(Node3D *game,double delta,const Dictionary &movement,const Array &weapons,bool native_trace);
};
}
