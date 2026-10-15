#pragma once
#include "authority_cq.h"
namespace cqauthority {
inline const V transport_size={3.51053799821,2.8209746516,8};
inline constexpr double transport_entry_radius=1.6;
struct TransportPod { V entry, seat; };
inline const std::array<TransportPod,8> transport_pods{{
 {{-2.20509629799,0,-0.858049304244},{-1.17876460407,0.690441596679,-0.858049304244}},
 {{-2.20509629799,0,0.219046852728},{-1.17876460407,0.690441596679,0.219046852728}},
 {{-2.20509629799,0,1.29635350338},{-1.17876460407,0.690441596679,1.29635350338}},
 {{2.20509629799,0,-0.858049304244},{1.17876460407,0.690441596679,-0.858049304244}},
 {{2.20509629799,0,0.219046852728},{1.17876460407,0.690441596679,0.219046852728}},
 {{2.20509629799,0,1.29635350338},{1.17876460407,0.690441596679,1.29635350338}},
 {{-2.2,0,-2.65},{-0.63,0.4,-2.65}},
 {{2.2,0,-2.65},{0.63,0.4,-2.65}},
}};
inline V transport_seat(const Vehicle &v, int seat) {
 return V{v.position.x,v.visual_y,v.position.z}+vehicle_basis(v).apply(transport_pods[size_t(seat)].seat);
}
}
