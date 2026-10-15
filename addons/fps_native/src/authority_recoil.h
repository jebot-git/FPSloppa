#pragma once
#include "authority_math.h"
namespace cqauthority {
// CS recovery, movement bloom and unsupported-long-gun penalty in typed state.
struct RecoilState {
  double heat=0, shot_at=-10, support_at=-10;
  V support_angles, step;
  double compensation(V axis,double stamp,bool supported) {
    if(!supported || axis.length()<.075 || axis.length()>1.1) {support_at=-10;return 1;}
    V angles{std::atan2(axis.y,-axis.z),std::atan2(-axis.x,-axis.z),0};
    double scale=1;
    if(stamp>support_at && stamp-support_at<=.25) {
      V change{std::remainder(angles.x-support_angles.x,2*3.141592653589793),std::remainder(angles.y-support_angles.y,2*3.141592653589793),0};
      if(change.length()<=20*3.141592653589793/180 && step.length2()>1e-12) {
        double counter=std::max(0.,-change.dot(step.unit())-.08*3.141592653589793/180);
        scale=1-.5*std::clamp(counter/std::max(step.length(),.25*3.141592653589793/180),0.,1.);
      }
    }
    if(stamp>support_at){support_angles=angles;support_at=stamp;}
    return scale;
  }
  V shot(int slot,double now,double speed,bool ground,double height,bool vr,bool supported,double correction,double rx,double ry) {
    static constexpr double spread[12]={.6,.32,.45,.45,.28,0,0,0,0,.06,.65,0};
    static constexpr double bloom[12]={.35,.24,.3,.12,.18,0,0,0,0,0,.5,0};
    heat=std::max(0.,heat-std::max(0.,now-shot_at-.12)*5.);
    bool long_gun=slot==1||slot==3||slot==4||slot==5||slot==11;
    double penalty=vr&&long_gun&&!supported?2:1;
    double extra=std::min(4.,heat)+(speed<.5?0:1.6)+(ground?0:4);
    double cone=(spread[slot]+extra)*penalty;
    if(heat==0&&speed<.5&&ground&&penalty==1)cone=0;
    double accuracy=ground?(height<.8?.45:height<1.6?.75:1):1;
    const double radians=3.141592653589793/180;
    double rise=vr?std::min(4.,heat)*.35*penalty:std::min(4.,heat)*.35;
    V result{rx*std::tan(cone*accuracy*radians),std::tan(rise*radians)+ry*std::tan(cone*accuracy*radians),-1};
    step={rise*radians,rx*cone*radians,0};
    heat=std::min(8.,heat+bloom[slot]*std::clamp(correction,.5,1.));shot_at=now;
    return result.unit();
  }
};
}
