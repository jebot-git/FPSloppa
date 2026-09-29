#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class FPSPose : public RefCounted {
 GDCLASS(FPSPose, RefCounted)
protected: static void _bind_methods();
public:
 void prepare_live(Skeleton3D *sk,Node3D *rig,Dictionary ids,const Dictionary &rest,Dictionary rotations,Dictionary floor_heights,bool sample_floor);
 void solve(Skeleton3D *sk, int a, int b, int c, Vector3 target, Vector3 pole);
 void rotate_toward(Skeleton3D *sk, int index, Vector3 source, Vector3 destination);
 void orient(Skeleton3D *sk, int index, Basis world);
 void fingers(Skeleton3D *sk, const PackedInt32Array &indices, const Array &rest, const PackedFloat32Array &curls);
 void capture(Skeleton3D *sk, const Dictionary &ids, Dictionary poses, const Array &moving, bool optimized);
 void blend(Skeleton3D *sk, const Array &rows, Dictionary shown, double weight);
};
}
