#pragma once
#include "authority_cq.h"
namespace cqauthority {
inline const V bike_size={1.14,1.25,3.4};
inline const V bike_seat_anchor={0.0,0.17,0.15};
inline V bike_seat(const Vehicle &v) { return V{v.position.x,v.visual_y,v.position.z}+vehicle_basis(v).apply(bike_seat_anchor); }
}
