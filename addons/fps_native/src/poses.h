#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/core/object_id.hpp>
#include <vector>
namespace godot {
class FPSPose : public RefCounted {
 GDCLASS(FPSPose, RefCounted)
 struct MorphSource {int index;double weight;};
 struct MorphChannel {ObjectID mesh;int shape;double limit;Array row;std::vector<MorphSource> sources;};
 std::vector<MorphChannel> morph_channels;
 StringName tracking_head{"head"},tracking_left{"left"},tracking_right{"right"},tracking_weapon{"weapon"},tracking_offhand{"offhand_weapon"},tracking_handed{"left_handed"},tracking_face{"face"},tracking_body{"body"};
protected: static void _bind_methods();
public:
 void configure_morphs(const Array &channels);
 int64_t compose_morphs(const Array &eyes,const PackedFloat32Array &mouth,bool dead);
 void interpolate_tracking(Dictionary shown,const Dictionary &target,double delta);
 void prepare_live(Skeleton3D *sk,Node3D *rig,Dictionary ids,const Dictionary &rest,Dictionary rotations,Dictionary floor_heights,bool sample_floor);
 void solve(Skeleton3D *sk, int a, int b, int c, Vector3 target, Vector3 pole);
 void rotate_toward(Skeleton3D *sk, int index, Vector3 source, Vector3 destination);
 void orient(Skeleton3D *sk, int index, Basis world);
 void fingers(Skeleton3D *sk, const PackedInt32Array &indices, const Array &rest, const PackedFloat32Array &curls);
 void capture(Skeleton3D *sk, const Dictionary &ids, Dictionary poses, const Array &moving, bool optimized);
 void blend(Skeleton3D *sk, const Array &rows, Dictionary shown, double weight);
};
}
