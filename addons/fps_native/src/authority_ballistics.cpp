#include "authority_cq.h"
#include "authority_transport_geometry.h"
namespace cqauthority {
const VehicleProfile &vehicle_profile(VehicleKind kind) {
  static const std::array<VehicleProfile, 4> profiles = {
      {{100,
        {4.5, 1.7, 4.8},
        10,
        5,
        .65,
        4,
        8,
        30,
        .15,
        1,
        -89,
        89,
        {0, 2.3, 0},
        2.65,
        .55},
       {250,
        {2.2, 1, 4.8},
        10,
        5,
        .65,
        4,
        5,
        10,
        1.5,
        1,
        -2,
        35,
        {0, .88044, 1.30787},
        3.46838,
        0},
       {500,
        {3.2, 1.2, 5.8},
        6,
        3,
        .35,
        2.5,
        4,
        15,
        1.5,
        2,
        -4,
        25,
        {0, 1.06728, 1.30121},
        3.79844,
        .18},
       {100,transport_size,10,5,.65,4,0,0,0,0,0,0,{},0,0}}};
  return profiles[size_t(kind)];
}
Ballistic ballistic(V start, V target, double speed, double gravity,
                    V inherited, bool high) {
  if (speed <= 0 || gravity <= 0 || !start.finite() || !target.finite() ||
      !inherited.finite())
    return {};
  V span=target-start;double range=std::hypot(span.x,span.z);
  if(inherited.length2()<1e-12 && range>1e-6){
    double v2=speed*speed,disc=v2*v2-gravity*(gravity*range*range+2*span.y*v2);
    if(disc < -v2*v2*1e-10)return {};
    double tangent=(v2+(high?1:-1)*std::sqrt(std::max(0.,disc)))/(gravity*range);
    double horizontal=speed/std::sqrt(1+tangent*tangent),flight=range/horizontal;
    V velocity=V{span.x/range*horizontal,horizontal*tangent,span.z/range*horizontal};
    return {true,velocity,velocity.unit(),target,flight};
  }
  auto error = [&](double t) {
    return ((target - start) / t + V{0, gravity * t * .5, 0} - inherited)
               .length2() -
           speed * speed;
  };
  double previous = .025, previous_error = error(previous);
  Ballistic result;
  double step=std::clamp(2*(speed+inherited.length())/gravity+5.,10.,120.)/400.;
  for (int i = 1; i <= 400; ++i) {
    double time = i * step, e = error(time);
    if (e * previous_error <= 0) {
      double low = previous, upper = time;
      for (int step = 0; step < 18; ++step) {
        double middle = (low + upper) * .5;
        if (error(low) * error(middle) <= 0)
          upper = middle;
        else
          low = middle;
      }
      double flight = (low + upper) * .5;
      V velocity = (target - start) / flight + V{0, gravity * flight * .5, 0};
      result = {true, velocity, (velocity - inherited).unit(), target, flight};
      if (!high)
        return result;
    }
    previous = time;
    previous_error = e;
  }
  return result;
}
B vehicle_basis(const Vehicle &v) {
  V normal = v.normal.unit(), forward = B::yaw(v.yaw).apply({0, 0, -1}),
    right = forward.cross(normal).unit();
  return {right, normal, normal.cross(right).unit() * -1};
}
V vehicle_pivot(const Vehicle &v) {
  return V{v.position.x, v.visual_y, v.position.z} +
         vehicle_basis(v).apply(vehicle_profile(v.kind).pivot);
}
V vehicle_muzzle(const Vehicle &v, int barrel) {
  auto &p = vehicle_profile(v.kind);
  V side = v.direction.cross(v.normal).unit();
  return vehicle_pivot(v) + v.direction * p.length +
         side * (barrel % 2 ? -p.offset : p.offset);
}
} // namespace cqauthority
