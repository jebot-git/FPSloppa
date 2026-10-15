#pragma once
#include "authority_math.h"
#include <array>
#include <cstdint>
namespace cqauthority {
constexpr size_t MAX_ZONES = 32, MAX_BOXES = 384, MAX_FIELDS = 128,
                 MAX_TURRETS = 128, MAX_VEHICLES = 32, MAX_FLIGHTS = 128,
                 MAX_GRENADES = 384;
enum class Role : uint8_t { SHOCKTROOP, SCOUT, MEDIC, TECHNICIAN };
enum class DamageKind : uint8_t {
  BULLET,
  ENERGY,
  ORDNANCE,
  GRENADE,
  MELEE,
  FALL,
  WATER,
  BLEEDOUT,
  VEHICLE_DESTROYED,
  RUNOVER,
  HEAVY_RUNOVER,
  COLLAPSE
};
struct Session {
  int64_t id = 0;
  uint32_t token = 0;
  bool operator==(Session b) const { return id == b.id && token == b.token; }
  bool operator!=(Session b) const { return !(*this == b); }
};
struct ClassState {
  Role role = Role::SHOCKTROOP, next = Role::SHOCKTROOP;
  std::array<int, 4> xp{};
  std::array<bool, 4> primary_t2{}, secondary_t2{}, utility_t2{};
  bool equipped_t2 = false;
  double box_ready = 0, cloak_until = 0, cloak_ready = 0, drone_ready = 0,
         strike_ready = 0, turret_ready = 0, nvg_ready = 0, blind_until = 0;
  bool nvg = false;
  int armor_limit() const { return role == Role::SHOCKTROOP ? 100 : role == Role::SCOUT ? 0 : 50; }
  int level() const { return std::max(0, xp[size_t(role)]) / 500; }
  int box_limit() const { return std::clamp(level() / 5, 1, 3); }
  bool replaces_box() const {
    return equipped_t2 && (role == Role::MEDIC || role == Role::TECHNICIAN);
  }
  bool choose(int role, int slot, int value);
  int weapon(bool secondary) const;
  void award(int amount);
};
struct Zone {
  V position;
  double radius = 3;
  int owner = -1;
  std::array<double, 2> progress{};
  double credit = 0;
  bool contested = false;
};
struct Points {
  std::array<Zone, MAX_ZONES> zones{};
  size_t count = 0;
  std::array<int, 2> scores{};
  int winner = -2;
  int held(int team) const;
  void decide();
  int kill(int team);
  void advance(double delta,
               const std::array<std::array<bool, 2>, MAX_ZONES> &,
               const std::array<std::array<int, 2>, MAX_ZONES> &counts = {});
};
struct Box {
  bool active = false;
  uint64_t key = 0;
  Session owner;
  int team = 0;
  bool health = false;
  V position;
  int remaining = 1000;
  double xp_credit = 0;
  std::array<double, 128> credit{};
  std::array<uint32_t, 128> lives{};
};
struct Field {
  bool active = false;
  uint64_t key = 0;
  Session owner;
  int team = 0;
  V position;
  int health = 500;
  double energy = 500, until = 0, xp_credit = 0, hit_at = -100;
  std::array<double, 128> credit{};
  std::array<uint32_t, 128> lives{};
};
struct Designation {
  bool active = false;
  V start, position, direction;
  double until = 0, target_at = 0;
  V lock_position, lock_direction;
  bool locking = false;
};
struct CqConfig {
  int team_limit = 32; // Explicit experimental overrides do not change production defaults.
  int squad_limit() const { return team_limit / 4; }
  bool enabled = false;
  double map_limit = 1414.213562373095, fall_limit = -200, water_level = -1e9;
  double light_fraction = 1;
  bool auto_respawn = true, day_cycle = false, squads = false;
  double cycle_seconds = 1200, cycle_offset = 0, round_seconds = 0,
         intermission_seconds = 10;
};
} // namespace cqauthority
namespace cqauthority {
enum class ActionKind : uint8_t {
  USE,
  NVG,
  GRENADE_ARM,
  GRENADE_THROW,
  CANCEL,
  CLASS,
  GEAR,
  SUICIDE,
  TEAM,
  GRENADE_EQUIP,
  DEPLOY,
  SQUAD,
  SPAWN
};
struct Action {
  int64_t seq = -1;
  ActionKind kind = ActionKind::USE;
  int a = 0, b = 0, c = 0;
};
struct Grenade {
  bool active = false, ground = false;
  uint64_t key = 0;
  Session owner;
  uint32_t life = 0;
  int team = 0, kind = 0;
  V position, velocity;
  double age = 0;
};
} // namespace cqauthority
namespace cqauthority {
constexpr double ROCKET_TANK_RANGE = 5000, ROCKET_TANK_SPEED = 316.22776601683796, ROCKET_TANK_FUSE = 90;
enum class VehicleKind : uint8_t { ROCKET, LIGHT, HEAVY, TRANSPORT };
struct VehicleProfile {
  double hp = 100;
  V size{4.5, 1.7, 4.8};
  double forward = 10, reverse = 5, turn = .65, acceleration = 4;
  int capacity = 8;
  double reload = 30, interval = .15;
  int pair = 1;
  double pitch_min = -89, pitch_max = 89;
  V pivot{0, 2.3, 0};
  double length = 2.65, offset = .55;
};
const VehicleProfile &vehicle_profile(VehicleKind);
struct Vehicle {
  bool active = false, grounded = false, stable_ground = false, headlights = false, headlight_held = true;
  uint64_t key = 0;
  VehicleKind kind = VehicleKind::ROCKET;
  V spawn, position, velocity, direction{0, 0, -1}, normal{0, 1, 0},
      barrage_center;
  double spawn_yaw = 0, yaw = 0, speed = 0, fall_speed = 0, hp = 100,
         visual_y = 0, next = 0, reload_at = 0, shot_at = -100,
         barrage_time = 0, barrage_phase = 0, respawn_at = 0;
  int team = -1, spawn_team = -1, remaining = 0, rounds = 8;
  Handle pilot;
  std::array<Handle,8> seats{};
};
struct VehicleMoved {
  V position, velocity, normal{0, 1, 0};
  double visual_y = 0;
  bool grounded = false, stable_ground = false;
};
struct Turret {
  bool active = false;
  uint64_t key = 0;
  Session owner;
  Handle gunner;
  int team = 0;
  V position, direction{0, 0, -1};
  double hp = 200, fire_at = 0, shot_at = -100;
  int ammo = 12;
  uint64_t target_vehicle = 0;
  Handle target_player;
};
struct Flight {
  bool active = false;
  uint64_t key = 0;
  bool strike = false;
  Session owner;
  Handle caller;
  int team = 0;
  V start, direction, target;
  double length = 0, at = 0, until = 0, impact_at = 0, step = 0, last_scan = 0;
  int delivered = 0;
  std::array<uint32_t, 128> seen_lives{};
};
struct Ballistic {
  bool valid = false;
  V velocity, direction, target;
  double time = 0;
};
Ballistic ballistic(V start, V target, double speed, double gravity,
                    V inherited = {}, bool high = false);
B vehicle_basis(const Vehicle &);
V vehicle_pivot(const Vehicle &);
V vehicle_muzzle(const Vehicle &, int barrel = 0);
} // namespace cqauthority

namespace cqauthority {
enum class EventKind : uint8_t {
  SHOT,
  IMPACT,
  EXPLOSION,
  RECON_ALERT,
  AIRSTRIKE,
  VEHICLE_DESTROYED,
  MELEE,
  RAY,
  GRENADE,
  HURT
};
struct Event {
  uint64_t seq = 0;
  EventKind kind = EventKind::IMPACT;
  Handle actor;
  uint64_t entity = 0;
  V position, direction;
  double at = 0, value = 0;
  int detail = 0;
};
} // namespace cqauthority
