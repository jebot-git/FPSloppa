#pragma once
#include "authority_math.h"
namespace cqauthority {
inline bool nvg_direct(V forward,V direction,bool sun=false) {
 return direction.length2()>1e-9 && forward.unit().dot(direction.unit())>
        std::cos((sun?1.:2.5)*3.141592653589793/180.);
}
}
