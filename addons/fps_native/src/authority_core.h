#pragma once
// Host-independent resident authority. No Godot types or scene ownership.
#include "authority_collision.h"
#include "authority_cq.h"
#include "authority_melee.h"
#include "authority_terrain.h"
#include "authority_vr.h"
#include "authority_recoil.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <vector>
namespace cqauthority {
constexpr size_t MAX_PLAYERS = 128, INPUT_DEPTH = 32, MAX_PROJECTILES = 2048;
constexpr double DT = 1.0 / 30.0;
struct Command {
  Command();
  uint32_t life = 0;
  int64_t seq = -1;
  double x = 0, z = 0, yaw = 0, pitch = 0;
  int weapon = 2;
  double view_time = -1;
  uint32_t jump_event = 0, jetpack_event = 0, fire_event = 0;
  int64_t jump_seq = -1;
  uint8_t fire_mask = 0, fire_weapon = 0;
  Pose pose;
  V room;
  double stamp = 0;
  bool weapon_held = true;
  bool reload_trigger = false;
  bool vr = false, reload_grip = false, jetpack = false, offhand_fire = false,
       respawn = false, drag = false, melee = false;
  bool fire = false, jump = false, reload = false, slow = false, crouch = false,
       prone = false, blocked = false;
};
struct Weapon {
  int ammo = -1, mag = 0;
  double cycle = 0, damage = 0, speed = 0, gravity = 0, range = 0, splash = 0,
         radius = 0, reload = 2.2;
  int burst = 1, salvo = 1;
  double charge = 0;
};
const std::array<Weapon, 12> &weapons();
struct Motion {
  Handle actor;
  V position, velocity;
  double height = 1.65, yaw = 0;
  bool grounded = false, step = false;
};
struct Moved {
  V position, velocity;
  double height = 1.65;
  bool grounded = false, ceiling = false;
};
struct Hit {
  bool blocked = false;
  Handle actor;
  V position;
  V normal{0, 1, 0};
  bool headshot = false;
  double fraction = infinity;
  uint64_t entity = 0;
  uint8_t entity_kind = 0;
};
struct Host {
  virtual ~Host() = default;
  virtual bool edge(const Motion &) { return false; }
  virtual double posture(Handle, double requested) { return requested; }
  virtual Moved move(const Motion &, double) = 0;
  virtual Hit trace(V, V, Handle) = 0;
  virtual Hit world_trace(V, V, Handle) { return {}; }
  virtual Hit sweep_world(V from, V to, double, Handle who, uint64_t) {
    return trace(from, to, who);
  }
  virtual double world_fraction(V, V, double, Handle) { return infinity; }
  virtual double ground_height(double, double) { return 0; }
  virtual std::vector<V> navigate(V, V to) { return {to}; }
  virtual Hit entity_ray(V a, V b, uint64_t) { return world_trace(a, b, {}); }
  virtual bool clear_exit(Handle, V, uint64_t) { return true; }
  virtual void seat(Handle h, V at, bool) { teleport(h, at); }
  virtual void sync_vehicle(const Vehicle &) {}
  virtual VehicleMoved move_vehicle(const Vehicle &v, V velocity, double dt) {
    return {v.position + velocity * dt,
            velocity,
            v.normal,
            v.visual_y,
            false,
            false};
  }
  virtual void teleport(Handle, V) {}
  virtual bool water(V) { return false; }
  virtual V room_move(Handle, V requested, double yaw) {
    return B::yaw(yaw).apply(requested);
  }
};
struct Player {
  Player();
  Handle handle;
  int team = 0, squad = -1;
  double combat_until = 0;
  bool active = false, dead = false, grounded = false, jump_held = false,
       bot = false, stress = false, staging = false;
  V position, velocity;
  Pose pose;
  V previous_position;
  V spawn_position;
  std::array<Action, 16> actions{};
  size_t action_head = 0, action_count = 0;
  int64_t action_seq = -1;
  bool nvg_pending = false;
  V throw_velocity;
  uint64_t lock_vehicle = 0;
  double lock_elapsed = 0;
  double melee_ready = 0;
  std::array<MeleeState, 2> melee_state;
  double repair_credit = 0;
  double grenade_ready = 0, grenade_until = 0, use_ready = 0;
  uint32_t session_token = 0;
  ClassState classes;
  bool incapacitated = false;
  double bleed_remaining = 0, inject_progress = 0, invulnerable = 0,
         respawn_at = 0;
  uint64_t injury_tick = 0, inject_touched = 0;
  Handle injector, injury_source;
  Session injury_credit;
  int injury_weapon = -1;
  bool death_gibbed = false;
  double armor_credit = 0;
  int armor = 0, armor_tier = 1, vehicle = -1, vehicle_seat = -1, grenade_count = 0;
  bool grenade_primed = false, grenade_selected = false,
       grenade_offhand = false, grenade_trigger = false;
  double grenade_pin_at = 0;
  Designation designation;
  std::array<double, 2> spotted{};
  ReachProfile reach;
  RecoilState recoil;
  V room;
  double pose_stamp = 0, cycle_at = 0;
  int cycling = -1;
  bool jetpack_enabled = false, reload_held = false, profile_loaded = false,
       want_respawn = false;
  Jetpack jetpack;
  std::array<Reload, 12> physical;
  double height = 1.65, hp = 100, yaw = 0, pitch = 0, stamina = 0, cooldown = 0,
         reload_at = 0, charge_at = 0, next_shot = 0, last_input = -1e9;
  uint16_t owned = 0;
  int weapon = 2, reloading = -1, burst_left = 0, salvo_left = 0, kills = 0,
      deaths = 0;
  uint64_t shots = 0;
  int64_t last_seq = -1;
  std::array<int, 4> ammo{}, spawn_ammo{};
  std::array<int, 12> clips{};
  Command input;
  std::array<Command, INPUT_DEPTH> queue{};
  size_t head = 0, count = 0;
  bool press_pending = false, jump_pending = false, jet_event_pending = false,
       burst_held = false;
  uint32_t jump_ack = 0, jetpack_ack = 0, fire_ack = 0;
};
struct Projectile {
  bool active = false;
  Handle owner;
  int team = 0;
  V position, velocity;
  double damage = 0, splash = 0, radius = 0, gravity = 0, remaining = 0;
  uint64_t key = 0;
  int weapon = 0;
  double sweep_radius = .025, age = 0, arm = 0, bounce = 0;
  bool quake = false, fresh = true, stuck = false;
  int direct_random = 0;
  uint64_t ignore_entity = 0, target_vehicle = 0;
  Session credit;
  uint8_t effect = 0;
};
struct Counters {
  uint64_t accepted = 0, rejected = 0, overflow = 0, shots = 0, damage = 0,
           deaths = 0, projectile_full = 0;
};
struct Timings {
  double movement_us = 0, combat_us = 0, snapshot_us = 0, ai_us = 0,
         mode_us = 0;
};
class Core {
  int tick_hz_ = 30;
  double step_ = DT;
  std::array<Player, MAX_PLAYERS> players_{};
  struct BotBrain {
    Handle life, target;
    V goal, last_position, aim;
    std::vector<V> path;
    size_t step = 0;
    double think = 0, plan = 0, route = 0, tool_until = 0,
           designation_until = 0, stuck = 0;
    int tool = 0;
  };
  std::array<BotBrain, MAX_PLAYERS> brains_{};
  void tick_bots(Host &);
  std::array<Projectile, MAX_PROJECTILES> projectiles_{};
  std::array<Box, MAX_BOXES> boxes_{};
  std::array<Field, MAX_FIELDS> fields_{};
  std::array<Grenade, MAX_GRENADES> grenades_{};
  std::array<Vehicle, MAX_VEHICLES> vehicles_{};
  std::array<Turret, MAX_TURRETS> turrets_{};
  std::array<Flight, MAX_FLIGHTS> flights_{};
  std::array<Event, 1024> events_{};
  size_t event_next_ = 0, event_count_ = 0;
  uint64_t next_event_ = 1;
  void emit(EventKind, Handle, V, V = {}, int = 0, double = 0, uint64_t = 0);
  bool deploy_turret(Player &, V, Host &);
  void tick_turrets(Host &);
  void tick_locks(Host &);
  bool recon(Player &, Host &);
  bool airstrike(Player &, Host &);
  void tick_flights(Host &);
  void snapshot_entities();
  void repair(Player &, Host &);
  void drag(Player &, Host &);
  void melee(Player &, Host &);
  void tick_lighting(Host &);
  void round_state(Host &);
  std::array<std::vector<V>, 2> spawns_;
  V spawn_site(const Player &, Host &);
  bool ground_spawn(const Player &, V, Host &, V &);
  bool squad_deploy(Player &, int, int, int, Host &);
  std::vector<V> lamps_;
  std::unordered_map<uint64_t, std::vector<size_t>> lamp_bins_;
  double round_start_ = 0, restart_at_ = 0;
  uint32_t round_epoch_ = 1;
  bool round_awarded_ = false, restart_requested_ = false;
  uint64_t random_state_ = 0x243f6a8885a308d3ULL;
  double random_unit();
  bool vehicle_use(Player &, Host &);
  bool vehicle_leave(Player &, Host &, bool forced = false);
  void destroy_vehicle(Vehicle &, Handle, Host &, bool, Session = {});
  void respawn_vehicle(Vehicle &, Host &);
  void tick_vehicles(Host &);
  bool launch_external(Handle, int, int, V, V, double, double, double, double,
                       double, double, uint64_t = 0, uint64_t = 0,
                       Session = {});
  double field_delta_ = 0;
  size_t field_cursor_ = 0;
  void actions(Player &, Host &);
  bool throw_grenade(Player &, Host &);
  void tick_grenades(Host &);
  bool activate_field(Session, int, V);
  void tick_fields(Host &);
  double energy_intercept(int, V, V, double, V &);
  uint64_t next_entity_ = 1;
  void spawn_class(Player &);
  void trim_boxes(Session, int);
  int supply(Box &, Player &, int);
  struct HistoricActor {
    bool active = false;
    Handle handle;
    V position;
    double height = 1.65, yaw = 0;
  };
  struct HistoryFrame {
    double time = 0;
    std::array<HistoricActor, MAX_PLAYERS> actors;
  };
  std::array<HistoryFrame, 16> history_{};
  size_t history_next_ = 0, history_count_ = 0;
  void record_history();
  double damage_yaw(const Player &) const;
  Hit trace_hit(Host &, V, V, Handle, double radius = 0, double view_time = -1,
                bool relative = false, uint64_t ignore_entity = 0);
  void tick_classes(Host &);
  void utility(Player &, Host &);
  Player *owner(Session);
  Session session(const Player &) const;
  bool alive(const Player &) const;
  bool same_team(const Player &, const Player &) const;
  T weapon_pose(const Player &, bool offhand = false) const;
  T eye_pose(const Player &) const;
  bool stationary(const Player &) const;
  double time_ = 0;
  uint64_t tick_ = 0;
  uint64_t clock_units_ = 0, snapshot_tick_ = 0; // One unit is 1/60 second.
  uint32_t next_life_ = 1;
  std::vector<uint8_t> frame_;
  void consume(Player &);
  void movement(Player &, Host &);
  void combat(Player &, Host &);
  bool magazines(Player &);
  void consume_ammo(Player &, int);
  bool fire(Player &, Host &, bool paid = false);
  void projectiles(Host &);
  void impact(const Projectile &, const Hit &, Host &);
  void snapshot();
  void snapshot_extended();
  void snapshot_cq();
  uint64_t next_projectile_ = 1;

public:
  bool extended_frames = false;
  CqConfig cq;
  Terrain terrain;
  Points points;
  Counters counters;
  Timings timings;
  Core();
  bool configure_tick_rate(int hz);
  bool transition_tick_rate(int hz);
  uint64_t snapshot_tick() const { return snapshot_tick_; }
  int tick_rate() const { return tick_hz_; }
  double step_seconds() const { return step_; }
  Player *find(int64_t);
  const Player *find(int64_t) const;
  Player *resolve(Handle);
  Handle join(int64_t, int, V, uint16_t, std::array<int, 4>);
  bool leave(Handle);
  Handle respawn(Handle, V);
  bool submit(Handle, const Command &);
  bool submit_packet(int64_t peer_id, const uint8_t *data, size_t size);
  bool damage(Handle victim, Handle source, double amount,
              DamageKind kind = DamageKind::BULLET, bool headshot = false,
              Session = {}, int weapon = -1);
  void request_restart() { restart_requested_ = true; }
  bool configure_cq(const CqConfig &);
  bool configure_lamps(const std::vector<V> &);
  bool configure_spawn(int, V);
  double round_remaining() const {
    return cq.round_seconds > 0
               ? std::max(0., cq.round_seconds - time_ + round_start_)
               : 0;
  }
  double intermission() const { return std::max(0., restart_at_ - time_); }
  uint32_t round_epoch() const { return round_epoch_; }
  int add_vehicle(VehicleKind, V, double yaw = 0, int team = -1);
  int damage_vehicle(uint64_t, int, double, DamageKind, Handle, Host &,
                     Session = {});
  const auto &vehicles() const { return vehicles_; }
  const auto &turrets() const { return turrets_; }
  const auto &flights() const { return flights_; }
  const auto &events() const { return events_; }
  const auto &grenades() const { return grenades_; }
  bool configure_zone(V, double radius = 3);
  bool configure_player(Handle, const ClassState &);
  bool configure_stress(Handle, bool);
  int squad_size(int team, int squad) const;
  bool join_squad(Handle, int squad);
  bool choose_class(Handle, int);
  bool choose_gear(Handle, int role, int slot, int value);
  bool deploy_box(Handle, V);
  bool inject(Handle, Handle, double);
  bool toggle_nvg(Handle);
  bool queue_action(Handle, const Action &);
  double spot_range(const Player &) const;
  const auto &boxes() const { return boxes_; }
  const auto &fields() const { return fields_; }
  void advance(Host &);
  double time() const { return time_; }
  uint64_t tick() const { return tick_; }
  const auto &players() const { return players_; }
  const auto &projectiles_state() const { return projectiles_; }
  const auto &frame() const { return frame_; }
};
} // namespace cqauthority
