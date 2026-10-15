#include "authority.h"
#include <godot_cpp/classes/box_shape3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
using namespace godot;
namespace {
Vector3 gv(cqauthority::V v) { return {real_t(v.x), real_t(v.y), real_t(v.z)}; }
cqauthority::V cv(Vector3 v) { return {v.x, v.y, v.z}; }
} // namespace
int FPSAuthority::collapse_region(const Vector3 &minimum, const Vector3 &maximum) {
  if (!on_owner()) return 0;
  return core.collapse_region(cv(minimum), cv(maximum), *this);
}
Node3D *FPSAuthority::world() const {
  auto *root = Object::cast_to<Node3D>(ObjectDB::get_instance(world_node));
  if (root && root->is_inside_tree())
    return root;
  for (auto &a : actors)
    if (auto *b = body(a.first))
      return Object::cast_to<Node3D>(b->get_parent())
                 ? Object::cast_to<Node3D>(b->get_parent())
                 : b;
  return nullptr;
}
bool FPSAuthority::configure_world(Node3D *node) {
  if (!on_owner() || advancing || core.tick() || !node ||
      !node->is_inside_tree())
    return false;
  world_node = node->get_instance_id();
  return true;
}
int FPSAuthority::attach_vehicle(int kind, CharacterBody3D *node, double yaw, int team) {
  if (!on_owner() || advancing || kind < 0 || kind > 3 || !node ||
      !node->is_inside_tree() || !std::isfinite(yaw) ||
      entity_identities.count(uint64_t(node->get_instance_id())))
    return -1;
  int index = core.add_vehicle(cqauthority::VehicleKind(kind),
                               cv(node->get_global_position()), yaw, team);
  if (index < 0)
    return -1;
  auto &v = core.vehicles()[index];
  entity_bodies[v.key] = node->get_instance_id();
  entity_identities[uint64_t(node->get_instance_id())] = v.key;
  node->set_collision_layer(1);
  node->set_collision_mask(1);
  node->set_floor_snap_length(.45);
  node->set_floor_max_angle(Math::deg_to_rad(30.));
  node->set_floor_stop_on_slope_enabled(true);
  node->set_max_slides(4);
  return index;
}
cqauthority::Hit FPSAuthority::contact(const Dictionary &result) const {
  cqauthority::Hit hit;
  if (result.is_empty())
    return hit;
  hit.blocked = true;
  hit.position = cv(result.get("position", result.get("point", Vector3())));
  hit.normal = cv(result.get("normal", Vector3(0, 1, 0)));
  uint64_t instance = result.get("collider_id", 0);
  auto actor = identities.find(instance);
  if (actor != identities.end())
    hit.actor = actor->second;
  auto entity = entity_identities.find(instance);
  if (entity != entity_identities.end()) {
    hit.entity = entity->second;
    for (auto &v : core.vehicles())
      if (v.active && v.key == hit.entity) {
        hit.entity_kind = 1;
        break;
      }
    if (!hit.entity_kind)
      hit.entity_kind = 2;
  }
  return hit;
}
cqauthority::Hit FPSAuthority::entity_ray(cqauthority::V a, cqauthority::V b,
                                          uint64_t ignore) {
  uint64_t previous = excluded_entity;
  excluded_entity = ignore;
  auto hit = world_trace(a, b, {});
  excluded_entity = previous;
  return hit;
}
double FPSAuthority::ground_height(double x, double z) {
  auto h = entity_ray({x, 2048, z}, {x, -512, z}, 0);
  return h.blocked ? h.position.y : 0;
}
void FPSAuthority::seat(cqauthority::Handle h, cqauthority::V at,
                        bool mounted) {
  if (auto *actor = body(h.id)) {
    actor->set_global_position(gv(at));
    actor->set_velocity(Vector3());
    actor->set_collision_layer(mounted ? 0 : 2);
    actor->set_collision_mask(mounted ? 0 : 3);
  }
}
void FPSAuthority::ordnance_impact(cqauthority::V at, double damage, double radius) {
  if (auto *node = world())
    if (node->has_method("cq_ordnance_impact"))
      node->call("cq_ordnance_impact", gv(at), damage, radius);
}
void FPSAuthority::sync_vehicle(const cqauthority::Vehicle &v) {
  auto it = entity_bodies.find(v.key);
  if (it == entity_bodies.end())
    return;
  auto *node =
      Object::cast_to<CharacterBody3D>(ObjectDB::get_instance(it->second));
  if (!node || !node->is_inside_tree())
    return;
  node->set_global_position(gv(v.position));
  node->set_rotation(Vector3(0, v.yaw, 0));
  node->set_collision_layer(v.hp > 0 ? 1 : 0);
  node->set_collision_mask(v.hp > 0 ? 1 : 0);
}
cqauthority::VehicleMoved
FPSAuthority::move_vehicle(const cqauthority::Vehicle &v,
                           cqauthority::V velocity, double) {
  auto it = entity_bodies.find(v.key);
  if (it == entity_bodies.end())
    return {v.position, {}, v.normal, v.visual_y, false, false};
  auto *node =
      Object::cast_to<CharacterBody3D>(ObjectDB::get_instance(it->second));
  if (!node || !node->is_inside_tree())
    return {v.position, {}, v.normal, v.visual_y, false, false};
  node->set_rotation(Vector3(0, v.yaw, 0));
  node->set_velocity(gv(velocity));
  node->move_and_slide();
  if (!node->is_on_floor())
    node->apply_floor_snap();
  Vector3 normal =
      node->is_on_floor() ? node->get_floor_normal() : Vector3(0, 1, 0);
  bool stable =
      node->is_on_floor() && normal.y >= Math::cos(Math::deg_to_rad(30.));
  double y = node->get_global_position().y;
  return {cv(node->get_global_position()),
          cv(node->get_velocity()),
          cv(normal),
          y + (v.kind == cqauthority::VehicleKind::ROCKET || v.kind == cqauthority::VehicleKind::TRANSPORT ? 0 : .25),
          node->is_on_floor(),
          stable};
}
bool FPSAuthority::clear_exit(cqauthority::Handle h, cqauthority::V at,
                              uint64_t ignore) {
  auto *root = world();
  if (!root)
    return false;
  Ref<CapsuleShape3D> shape;
  shape.instantiate();
  shape->set_radius(.3);
  shape->set_height(1.65);
  Ref<PhysicsShapeQueryParameters3D> query;
  query.instantiate();
  query->set_shape(shape);
  query->set_transform(Transform3D(Basis(), gv(at) + Vector3(0, .83, 0)));
  query->set_collision_mask(3);
  TypedArray<RID> exclude;
  if (auto *actor = body(h.id))
    exclude.push_back(actor->get_rid());
  auto it = entity_bodies.find(ignore);
  if (it != entity_bodies.end())
    if (auto *node = Object::cast_to<CollisionObject3D>(
            ObjectDB::get_instance(it->second)))
      exclude.push_back(node->get_rid());
  query->set_exclude(exclude);
  return root->get_world_3d()
      ->get_direct_space_state()
      ->intersect_shape(query, 1)
      .is_empty();
}
void FPSAuthority::sync_turrets() {
  auto *root = world();
  if (!root)
    return;
  for (auto &t : core.turrets()) {
    auto it = entity_bodies.find(t.key);
    if (t.active) {
      if (it == entity_bodies.end()) {
        auto *node = memnew(StaticBody3D);
        auto *collision = memnew(CollisionShape3D);
        Ref<BoxShape3D> box;
        box.instantiate();
        box->set_size(Vector3(1.2, 1.6, 1.2));
        collision->set_shape(box);
        collision->set_position(Vector3(0, .8, 0));
        node->add_child(collision);
        root->add_child(node);
        node->set_global_position(gv(t.position));
        node->set_collision_layer(1);
        node->set_collision_mask(3);
        entity_bodies[t.key] = node->get_instance_id();
        entity_identities[uint64_t(node->get_instance_id())] = t.key;
      }
    }
  }
  for (auto it = entity_bodies.begin(); it != entity_bodies.end();) {
    bool alive = false;
    for (auto &v : core.vehicles())
      if (v.active && v.key == it->first) {
        alive = true;
        break;
      }
    if (!alive)
      for (auto &t : core.turrets())
        if (t.active && t.key == it->first) {
          alive = true;
          break;
        }
    if (!alive) {
      if (auto *node =
              Object::cast_to<Node3D>(ObjectDB::get_instance(it->second))) {
        entity_identities.erase(uint64_t(it->second));
        node->queue_free();
      }
      it = entity_bodies.erase(it);
    } else
      ++it;
  }
}

Dictionary FPSAuthority::terrain_sample(const Vector3 &p) const {
  Dictionary d;
  if (!on_owner() || !p.is_finite())
    return d;
  auto water = core.terrain.water_sample(p.x, p.z);
  d["water"] = gv(water);
  d["road"] = core.terrain.road(cv(p));
  return d;
}
bool FPSAuthority::configure_lamps(const PackedVector3Array &lamps) {
  if (!on_owner() || advancing || lamps.size() > 8192)
    return false;
  std::vector<cqauthority::V> rows;
  rows.reserve(lamps.size());
  for (auto p : lamps)
    rows.push_back(cv(p));
  return core.configure_lamps(rows);
}

std::vector<cqauthority::V> FPSAuthority::navigate(cqauthority::V from,
                                                   cqauthority::V to) {
  auto *root = world();
  if (!root || !root->has_method("resident_navigation"))
    return {};
  Variant result = root->call("resident_navigation", gv(from), gv(to));
  if (result.get_type() != Variant::PACKED_VECTOR3_ARRAY)
    return {};
  PackedVector3Array path = result;
  std::vector<cqauthority::V> output;
  output.reserve(std::min(int64_t(64), path.size()));
  for (int64_t i = 0; i < std::min(int64_t(64), path.size()); ++i) {
    auto p = path[i];
    if (!p.is_finite())
      return {};
    output.push_back(cv(p));
  }
  return output;
}

FPSAuthority::~FPSAuthority() {
  if (!on_owner())
    return;
  for (auto &entry : entity_bodies) {
    bool borrowed = false;
    for (auto &v : core.vehicles())
      if (v.active && v.key == entry.first) {
        borrowed = true;
        break;
      }
    if (!borrowed)
      if (auto *node =
              Object::cast_to<Node3D>(ObjectDB::get_instance(entry.second)))
        node->queue_free();
  }
}

bool FPSAuthority::grass_cover(cqauthority::V at) {
  auto *root = world();
  return root && root->has_method("grass_cover_at") && bool(root->call("grass_cover_at", gv(at)));
}
