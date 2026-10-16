#pragma once
#include <array>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/object_id.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <memory>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>
namespace godot {
class FPSAvatar : public RefCounted {
  GDCLASS(FPSAvatar, RefCounted)
  struct Clip {
    String name;
    int start = 0, count = 1;
    double fps = 1;
  };
  struct Attachment {
    std::vector<Vector3> samples;
    Vector3 reference;
    bool present = false;
  };
  struct Model {
    uint32_t profile_hash = 0, clips_hash = 0;
    int reference_frame = 0;
    std::vector<Clip> clips;
    std::unordered_map<std::string, int> names;
    std::array<int, 8> choices{};
    std::vector<std::array<Vector3, 3>> sockets;
    std::array<std::array<Vector3, 3>, 2> arms;
    Vector3 neck, head, eye;
    Basis correction;
    bool corrected = false;
    std::array<Attachment, 3> attachments;
    std::array<Ref<Mesh>, 3> lods;
  };
  struct Actor {
    ObjectID rig, visual;
    std::shared_ptr<Model> model;
  };
  struct Arm {
    Transform3D upper, fore;
    Vector3 shoulder, elbow, hand, target;
    double upper_length, fore_length;
    bool clamped;
    Dictionary dictionary() const;
  };
  struct Head {
    Transform3D neck, head;
    Vector3 eye;
  };
  struct View {
    bool present = false, xr = false, orthogonal = false;
    Vector3 position;
    double scale = 1;
  };
  std::unordered_map<uint64_t, Actor> actors;
  std::unordered_map<uint64_t, std::weak_ptr<Model>> models;
  const std::thread::id owner_thread = std::this_thread::get_id();
  int64_t updated = 0, tracked = 0;
  double elapsed_us = 0;
  static View view(Camera3D *camera);
  static Vector3 socket(const Model &, Vector3 frames, int index);
  static Vector3 attachment(const Attachment &, Vector3 frames);
  static Arm solve_arm(const std::array<Vector3, 3> &, Vector3 shoulder,
                       Vector3 target, bool left);
  static Head solve_head(const Model &, Vector3 neck, Transform3D head);
  static void write_transform(MeshInstance3D *, int index, const Transform3D &);
  void advance_actor(Actor &, double delta, const View &);

protected:
  static void _bind_methods();

public:
  bool configure(Node3D *rig, const Array &clips, const Dictionary &profile,
                 const Array &lods);
  void detach(Node3D *rig);
  bool advance_one(Node3D *rig, double delta, Camera3D *camera);
  int advance(double delta, Camera3D *camera);
  Dictionary metrics() const;
};
} // namespace godot
