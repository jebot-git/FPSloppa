#include "authority_vr.h"
#include "authority_weapon_geometry.h"
namespace cqauthority {
bool Pose::valid() const {
  if (!std::isfinite(height))
    return false;
  if (!tracked)
    return true;
  if (!head.valid() || !left.valid() || !right.valid() || !weapon.valid() ||
      (has_offhand && !offhand.valid()) ||
      (has_height && !std::isfinite(height)))
    return false;
  V h = head.origin;
  if (std::hypot(h.x, h.z) > .75 || h.y < .05 || h.y > 3.2)
    return false;
  V torso{h.x, std::clamp(h.y - .45, .25, 2.7), h.z};
  if ((left.origin - torso).length() > 1.55 ||
      (right.origin - torso).length() > 1.55)
    return false;
  if ((weapon.origin - (left_handed ? left : right).origin).length() > .4)
    return false;
  return !has_offhand ||
         (offhand.origin - (left_handed ? right : left).origin).length() <= .4;
}
namespace {
V cone(V axis, V center, double limit) {
  axis = axis.unit();
  double angle = std::acos(std::clamp(center.dot(axis), -1., 1.));
  if (angle <= limit)
    return axis;
  V tangent = axis - center * axis.dot(center);
  if (tangent.length2() < .000001)
    tangent = {0, 0, -1};
  return center * std::cos(limit) + tangent.unit() * std::sin(limit);
}
} // namespace
T ReachProfile::weapon_pose(const Pose &pose, bool offhand) const {
  T result = offhand ? pose.offhand : pose.weapon;
  if (!enabled || !pose.tracked)
    return result;
  constexpr double pi = 3.141592653589793;
  V angles = pose.head.basis.euler_angles();
  angles.x = std::clamp(angles.x, -50 * pi / 180, 50 * pi / 180);
  angles.y = std::clamp(angles.y, -75 * pi / 180, 75 * pi / 180);
  angles.z = std::clamp(angles.z, -25 * pi / 180, 25 * pi / 180);
  B rotation = B::euler(angles).product(correction);
  V shift = (pose.head.origin - V{0, 1.65, 0}).limited(.065);
  V desired_eye = neck_socket + (eye - neck) + shift;
  V desired_pivot = desired_eye - rotation.apply(eye - head);
  V pivot = neck_socket +
            cone(desired_pivot - neck_socket, {0, 1, 0}, 40 * pi / 180) *
                (neck - head).length();
  V head_eye = pivot + rotation.apply(eye - head);
  bool left = pose.left_handed != offhand;
  V shoulder = left ? left_shoulder : right_shoulder;
  const V *rest = left ? left_rest : right_rest;
  V target =
      head_eye + (left ? pose.left : pose.right).origin - pose.head.origin;
  target.z = std::min(target.z, shoulder.z + .12);
  target.x = left ? std::min(target.x, .20) : std::max(target.x, -.20);
  if (std::abs(target.x) < .22 && target.y > .92 && target.y < 1.52)
    target.z = std::min(target.z, -.22);
  V displacement = target - shoulder;
  V axis =
      cone(displacement.length2() > .000001 ? displacement.unit() : V{0, -1, 0},
           {0, -1, 0}, 125 * pi / 180);
  double upper = (rest[0] - rest[1]).length(),
         fore = (rest[1] - rest[2]).length();
  double minimum = std::sqrt(upper * upper + fore * fore +
                             2 * upper * fore * std::cos(145 * pi / 180));
  double maximum = std::sqrt(upper * upper + fore * fore +
                             2 * upper * fore * std::cos(15 * pi / 180));
  result.origin =
      shoulder + axis * std::clamp(displacement.length(), minimum, maximum);
  return result;
}
void Pose::rebase(V d) {
  for (auto *p : {&head, &left, &right, &weapon, &offhand})
    p->origin = p->origin - d;
}
V room_request(V head) {
  V h{head.x, 0, head.z};
  if (!head.finite() || h.length() > .75)
    return {};
  return h.unit() * std::clamp(h.length() - .02, 0., .08);
}
V validate_room(V requested, const Pose &p) {
  if (!requested.finite() || !p.tracked)
    return {};
  V target = room_request(p.head.origin);
  return target.unit() *
         std::clamp(requested.dot(target.unit()), 0., target.length());
}
T hip_frame(const Pose &p) {
  auto at = p.head.origin;
  at.y -= std::clamp(at.y * .4, .23, .65);
  V facing{p.head.basis.z.x, 0, p.head.basis.z.z};
  if (facing.length2() < .001)
    facing = V{p.head.basis.x.x, 0, p.head.basis.x.z}.cross({0, 1, 0});
  return {B::yaw(std::atan2(facing.x, facing.z)), at};
}
bool pouch_contains(const Pose &p, V point) {
  V v = hip_frame(p).inverse(point);
  double side = p.left_handed ? 1 : -1;
  return point.finite() && v.x * side > .025 && v.y >= -.28 && v.y <= .24 &&
         (v.x / .58) * (v.x / .58) + (v.z / .48) * (v.z / .48) <= 1;
}
HandMotion sample_motion(MotionHistory &history, const Pose &pose,
                         double stamp) {
  auto hand = pose.left_handed ? pose.right : pose.left;
  MotionHistory current{true,
                        stamp,
                        pose.weapon.inverse(hand.origin) / .65,
                        pose.weapon.origin - pose.head.origin,
                        hand.origin - pose.head.origin,
                        pose.weapon.origin,
                        hand.origin,
                        pose.weapon.basis,
                        pose.head.basis};
  auto before = history;
  if (before.present && stamp <= before.time) {
    HandMotion duplicate;
    duplicate.duplicate = true;
    return duplicate;
  }
  history = current;
  if (!before.present)
    return {};
  HandMotion m;
  m.dt = stamp - before.time;
  m.hand_step = (current.hand - before.hand) * .65;
  m.weapon_step = before.basis.unapply(current.weapon - before.weapon);
  m.support_step = before.basis.unapply(current.support - before.support);
  if ((current.raw_weapon - before.raw_weapon).length() <
      m.weapon_step.length() * .35)
    m.weapon_step = {};
  if ((current.raw_support - before.raw_support).length() <
      m.support_step.length() * .35)
    m.support_step = {};
  m.valid = m.dt >= .008 && m.dt <= .16 && m.hand_step.length() < .32 &&
            m.weapon_step.length() < .32 && m.support_step.length() < .32;
  m.body_step = before.head_basis.unapply(before.basis.apply(m.weapon_step));
  return m;
}
void Reload::init(int clip) {
  *this = Reload{};
  initialised = true;
  ready = clip > 0;
  locked = clip == 0;
}
void Reload::interrupt() {
  grab = Grab::NONE;
  grip = true;
  trigger = true;
  eject = true;
  carry = 0;
  carried_rounds = 0;
  left_pouch = false;
  pulled = false;
  stroke = 0;
  motion = {};
}
void Reload::chamber(int clip) {
  ready = mag && clip > 0;
  locked = mag && clip == 0;
  stroke = 0;
  pulled = false;
  ++event;
}
void Reload::eject_mag(bool pack) {
  mag = false;
  ready = ready && !pack;
  pulled = false;
  stroke = 0;
  ++event;
}
bool Reload::can_fire(bool pack) const {
  return ready && grab != Grab::RACK && stroke < .05 && (!pack || mag);
}
int Reload::sample(int geometry, int clip, int total, int capacity,
                   const Pose &pose, bool held, bool eject_pressed, double now,
                   double stamp, bool magazine_trigger, bool separate_trigger) {
  if (!pose.tracked) {
    interrupt();
    return clip;
  }
  if (side != -1 && side != int(pose.left_handed))
    interrupt();
  side = int(pose.left_handed);
  const bool pack = geometry == 12;
  auto hand = pose.left_handed ? pose.right : pose.left;
  auto weapon = pose.weapon;
  V local = weapon.inverse(hand.origin) / .65;
  HandMotion m = sample_motion(motion, pose, stamp);
  if (geometry == 2 && locked && mag && clip > 0 && grab == Grab::NONE &&
      !held && m.valid) {
    double lateral =
        std::max(std::abs(m.weapon_step.x), std::abs(m.body_step.x));
    if (lateral >= .02 && lateral / m.dt >= .65)
      chamber(clip);
  }
  if (!pose.has_offhand) {
    if (geometry == 2 && grab == Grab::NONE) {
      grip = true;
      eject = eject_pressed;
      return clip;
    }
    interrupt();
    return clip;
  }
  V hip_hand = hip_frame(pose).inverse(hand.origin);
  bool pressed = held && !grip;
  bool eject_edge = eject_pressed && !eject;
  bool mag_held = separate_trigger ? magazine_trigger : held;
  bool mag_pressed = mag_held && !(separate_trigger ? trigger : grip);
  bool mag_released = !mag_held && (separate_trigger ? trigger : grip);
  bool rack_held = held || (separate_trigger && magazine_trigger);
  bool rack_released = !rack_held && (grip || (separate_trigger && trigger));
  grip = held;
  trigger = magazine_trigger;
  eject = eject_pressed;
  V mag_point = pack            ? V{-.1085, .08925, -.189}
                : geometry == 2 ? V{0, -.09, .02}
                                : V{0, -.06, .02};
  if (cq_weapon >= 0) mag_point = cq_geometry(cq_weapon).magazine;
  V direction = pack ? V{-1, 0, 0} : V{0, -1, 0};
  bool close = (hand.origin - weapon.apply(mag_point * .65)).length() < .095;
  bool aligned = pose.offhand.basis.y.dot(pose.weapon.basis.y) > .10;
  if (eject_edge && mag && grab != Grab::RACK && grab != Grab::MAGAZINE) {
    eject_mag(pack);
    clip = ready ? std::min(clip, 1) : 0;
  }
  if (grab == Grab::MAGAZINE) {
    if (mag_released) {
      grab = Grab::NONE;
      carry = 0;
      carried_rounds = 0;
      left_pouch = false;
    } else if (mag) {
      if (!m.valid && !m.duplicate) {
        anchor = local;
        started = now;
      } else if (m.valid && (local - anchor).dot(direction) * .65 >= .055 &&
                 now - started >= .06) {
        int loaded = clip;
        eject_mag(pack);
        clip = ready ? std::min(clip, 1) : 0;
        carry = 4;
        carried_rounds = loaded - clip;
        removed_depth = (local - anchor).dot(direction);
        started = now;
      }
    } else if (carry == 4 && m.valid) {
      double depth = (local - anchor).dot(direction);
      removed_depth = std::max(removed_depth, depth);
      if ((removed_depth - depth) * .65 >= .025 && close && aligned &&
          now - started >= .06) {
        clip = std::min(clip + carried_rounds, std::min(capacity, total));
        mag = true;
        if (pack)
          chamber(clip);
        carry = 0;
        carried_rounds = 0;
        left_pouch = false;
        grab = Grab::NONE;
        ++event;
      }
    }
  } else if (grab == Grab::AMMO) {
    if (mag_released) {
      carry = 0;
      carried_rounds = 0;
      left_pouch = false;
      grab = Grab::NONE;
    } else if (mag_held) {
      if ((hip_hand - anchor).length() > .12)
        left_pouch = true;
      if (left_pouch && close && aligned && now - started >= .15) {
        mag = true;
        clip = std::min(capacity, total);
        if (pack)
          chamber(clip);
        carry = 0;
        carried_rounds = 0;
        left_pouch = false;
        grab = Grab::NONE;
        ++event;
      }
    }
  } else if (grab == Grab::RACK) {
    if (rack_held) {
      stroke = std::clamp((local.z - anchor.z) / .065, 0., 1.);
      if (stroke > .90 && now - started >= .10)
        pulled = true;
      if (pulled && stroke < .12 && now - started >= .15) {
        chamber(clip);
        grab = Grab::NONE;
      }
    } else if (rack_released) {
      if (pulled)
        chamber(clip);
      else {
        stroke = 0;
        pulled = false;
      }
      grab = Grab::NONE;
    }
  } else if (pressed || mag_pressed) {
    V rack_point = (cq_weapon >= 0 ? cq_geometry(cq_weapon).rack : V{.04, .09, .055}) + V{0, 0, .065 * stroke};
    V rack_start = weapon.apply(rack_point * .65);
    V rack_end = rack_start + weapon.basis.y.unit() * (geometry == 2 ? .08 : 0);
    bool handguard = (geometry != 2 || cq_weapon >= 0) && (local - (cq_weapon >= 0 ? cq_geometry(cq_weapon).support : V{0, .015, -.15})).length() <
                                          (local - (cq_weapon >= 0 ? cq_geometry(cq_weapon).rack : V{.04, .09, .055})).length();
    if (mag_pressed && mag && (hand.origin - weapon.apply(mag_point * .65)).length() < .105) {
      grab = Grab::MAGAZINE;
      anchor = local;
      started = now;
      ++event;
    } else if ((pressed || (separate_trigger && mag_pressed)) && !pack &&
               (hand.origin - closest(hand.origin, rack_start, rack_end))
                       .length() < .105 &&
               !((ready || cq_weapon >= 0) && handguard)) {
      grab = Grab::RACK;
      anchor = local;
      started = now;
      pulled = false;
      stroke = 0;
      ++event;
    } else if (mag_pressed && total > clip && clip < capacity && !mag &&
               pouch_contains(pose, hand.origin)) {
      grab = Grab::AMMO;
      carry = 1;
      started = now;
      anchor = hip_hand;
      left_pouch = false;
      ++event;
    }
  }
  return clip;
}
void Reload::pack_delay(bool before_mag, int before_clip, int clip, double now,
                        double duration) {
  if (((before_mag && !mag) || clip > before_clip) && pack_until == 0)
    pack_until = now + duration;
  if (pack_until <= 0)
    return;
  ready = false;
  if (now >= pack_until && mag && clip > 0) {
    pack_until = 0;
    chamber(clip);
  }
}
bool Jetpack::tick(V &velocity, V direction, double dt, bool jump,
                   bool jump_held, bool requested, bool enabled, bool blocked,
                   bool prone) {
  time += dt;
  cooldown = std::max(0., cooldown - dt);
  tap = std::max(0., tap - dt);
  bool pressed = jump && !jump_held;
  if (!enabled)
    return false;
  if (blocked || prone) {
    tap = 0;
    pressed = false;
    requested = false;
  }
  bool double_tap = pressed && tap > 0;
  if (pressed)
    tap = .30;
  if ((double_tap || requested) && cooldown <= 0 && mode == 0) {
    V wish{direction.x, 0, direction.z};
    mode = wish.length() > .15 ? 1 : 2;
    heading = wish.unit();
    age = 0;
    distance = 0;
    cooldown = 8;
    tap = 0;
    ++activation;
    velocity = mode == 1 ? heading * 16 + V{0, 12, 0} : V{0, 8, 0};
  }
  if (mode == 0)
    return false;
  double old_age = age;
  age += dt;
  V wish{direction.x, 0, direction.z};
  if (mode == 1) {
    if (wish.length() > .15 && !blocked) {
      double angle = std::atan2(heading.x * wish.z - heading.z * wish.x,
                                heading.dot(wish));
      double turn = std::clamp(angle, -3.141592653589793 / 10 * dt,
                               3.141592653589793 / 10 * dt);
      double cs = std::cos(turn), sn = std::sin(turn);
      heading =
          V{heading.x * cs - heading.z * sn, 0, heading.x * sn + heading.z * cs}
              .unit();
    }
    double speed = std::min(std::max(0., 16 - std::max(0., age - 2) * 12),
                            std::max(0., 48 - distance) / dt);
    velocity.x = heading.x * speed;
    velocity.z = heading.z * speed;
    velocity.y = std::max(-30., velocity.y - (old_age < 2 ? 12 : 20) * dt);
  } else {
    if (blocked)
      wish = {};
    wish = wish.limited(1);
    V horizontal{velocity.x, 0, velocity.z};
    V target = wish * 2;
    horizontal =
        horizontal +
        (target - horizontal).limited((wish.length() > .05 ? 3 : 6) * dt);
    horizontal =
        horizontal.limited(std::min(2., std::max(0., 48 - distance) / dt));
    velocity.x = horizontal.x;
    velocity.z = horizontal.z;
    if (age < .7)
      velocity.y = std::max(0., 8 * (1 - age / .7));
    else if (age < 1.5)
      velocity.y = 0;
    else
      velocity.y = std::max(-30., velocity.y - 20 * dt);
  }
  return true;
}
void Jetpack::moved(V &velocity, V before, V after, bool floor, bool ceiling) {
  distance += std::hypot(after.x - before.x, after.z - before.z);
  if (ceiling && mode == 2 && age < .7)
    age = .7;
  if (floor && velocity.y <= 0) {
    mode = 0;
    tap = 0;
    V h = V{velocity.x, 0, velocity.z}.limited(9.4);
    velocity.x = h.x;
    velocity.z = h.z;
  }
}
} // namespace cqauthority
