#include "bots.h"
#include "bot_context.h"
using namespace godot;
using namespace godot::bot;
namespace {
const Vector3 up(0,1,0);
double clamp(double x,double lo,double hi){return std::min(std::max(x,lo),hi);}
Vector3 flat(Vector3 v){v.y=0;return v;}
bool ski(Vector3 normal,Vector3 direction,Vector3 velocity,double walk){
 double speed=velocity.length();if(normal.dot(direction)>.035)return true;if(normal.dot(direction)<-.035)return false;
 if(direction.is_zero_approx()||(speed>1&&velocity.normalized().dot(direction)<.65))return false;
 return speed>walk*1.05;
}
Vector3 jet(Vector3 velocity,Vector3 direction,const Dictionary &profile,const BotNames &k,double lift){
 Vector3 horizontal=flat(velocity),wish=(direction*std::max(n(profile,k.side_speed.value)*.95,double(horizontal.length()))-horizontal)*.12;
 if(wish.is_zero_approx())return wish;
 double share=clamp(1-horizontal.dot(wish.normalized())/n(profile,k.side_speed.value),0,.8),available=clamp(1-lift/n(profile,k.thrust.value),0,.8);
 return wish.limit_length(share>.001?std::min(1.,available/share):1.);
}
void recharge(Dictionary brain,double energy,double capacity,bool grounded,Vector3 offset,const BotNames &k){
 if(grounded&&energy<capacity*.85&&(offset.y>3||bool(brain.get(k.jet_recharge.value,false))))brain[k.jet_recharge.value]=true;
 if(energy>=capacity*.94)brain[k.jet_recharge.value]=false;if(energy<2)brain[k.jet_recharge.value]=true;
}
void finish(Context &c,int64_t id,Dictionary brain,Dictionary state,Vector3 target,Vector3 horizontal,Vector3 desired){
 const BotNames &k=c.k;
 bool look=int64_t(brain[k.enemy.value])==0||(bool(brain.get(k.travel_focus.value,false))&&!bool(brain.get(k.travel_defending.value,false)));
 if(look&&!one_of(s(brain,k.goal_kind.value),{"st_repair","st_destroy"})&&c.clock>=double(brain.get(k.equipment_aim_until.value,0))&&horizontal.length()>.5){Object *offense=c.tribes->get(k.offense.name);offense->call(k.travel_look.name,id,brain,target+up);}
 state[k.move.value]=c.tribes->call(k.movement.name,id,desired);state[k.prone.value]=false;state[k.crouch.value]=false;state[k.swim.value]=Vector3();
}
}

// Specialized objective/tower/recovery selection remains in the script. This
// batch owns corridor advancement, input math and live collision probes only.
void FPSBots::st_route(Object *ai,int64_t id,Dictionary brain,bool recharging){
 const BotNames &k=names;Context c(ai,ray,k);Node3D *actor=c.actor(id);Dictionary state=c.players[id],movement=actor->get(k.tribes_state.name);
 Object *rules=c.mode->get(k.tribes.name),*routes=c.tribes->get(k.routes.name),*avoidance=c.tribes->get(k.avoidance.name),*tactics=c.tribes->get(k.tactics.name);
 Dictionary profile=rules->call(k.definition.name,id);Vector3 position=actor->get_position(),full_velocity=actor->get(k.velocity.name),velocity=flat(full_velocity);
 double speed=velocity.length(),walk=n(profile,k.walk.value);bool grounded=actor->call(k.is_supported.name);Vector3 goal=brain[k.goal.value],target=goal;
 if(bool(c.tribes->call(k.reroute_after_fall.name,id,brain))||bool(c.tribes->call(k.reroute_below_deck.name,id,brain)))return;
 PackedVector3Array path=brain[k.path.value];int step=brain[k.step.value];
 if(step<path.size()){
  while(step<path.size()-1){
   Vector3 waypoint=path[step],offset=waypoint-position,horizontal=flat(offset);bool reached=horizontal.length()<2.3&&offset.y<2.8;
   if(step>0&&Vector2(waypoint.x-path[step-1].x,waypoint.z-path[step-1].z).length()>.01){
    Vector3 segment=flat(waypoint-path[step-1]),direction=segment.normalized();double along=-horizontal.dot(direction),sideways=horizontal.slide(direction).length();
    reached=reached||(along>0&&sideways<clamp(speed*.75,3,18)&&bool(routes->call(k.clear.name,position,path[step+1])));
   }
   if(offset.y < -3&&!c.ray(waypoint+up*.3,Vector3(waypoint.x,position.y+.3,waypoint.z)).is_empty())reached=false;
   if(step>0&&!reached)break;++step;brain[k.step.value]=step;
  }
  // The original range's upper bound is fixed before any step update.
  int stop=std::min(int(path.size()),step+5);
  for(int ahead=step+1;ahead<stop;++ahead){Vector3 candidate=path[ahead];if(candidate.distance_to(position)>clamp(speed*1.6,24,55)||!bool(routes->call(k.clear.name,position,candidate)))break;step=ahead;brain[k.step.value]=step;}
  target=path[step];
 }
 Vector3 offset=target-position,horizontal=flat(offset),direct=horizontal.normalized();double distance=horizontal.length();
 if(grounded&&offset.y < -3&&distance<9&&!c.ray(target+up*.3,Vector3(target.x,position.y+.3,target.z)).is_empty()){
  PackedVector3Array recovery=routes->call(k.path.name,position,goal,0,tactics->call(k.detours.name,id));
  if(!recovery.is_empty()){brain[k.path.value]=recovery;brain[k.step.value]=0;brain[k.route_at.value]=c.clock+12;return;}
 }
 bool ceiling=!c.ray(position+up*1.8,position+up*2.8).is_empty();Dictionary wall=avoidance->call(k.wall.name,position,position+direct*2);bool obstacle=!wall.is_empty();
 bool final=step>=path.size()-1;double thrust=n(profile,k.thrust.value),energy=n(movement,k.energy.value),capacity=n(profile,k.energy.value);
 bool precision=ceiling||(final&&distance<std::max(12.,speed*speed/thrust+3))||(offset.y>3&&offset.y>distance*.6);
 Vector3 desired;state[k.jump.value]=false;state[k.jet_held.value]=false;state[k.ski.value]=false;
 if(precision||(obstacle&&speed<walk*.5)){
  desired=(horizontal*.65-velocity*.7).limit_length(1);recharge(brain,energy,capacity,grounded,offset,k);
  if(grounded){state[k.jet_held.value]=(offset.y>1||obstacle)&&!ceiling&&!bool(brain.get(k.jet_recharge.value,false));state[k.jump.value]=b(state,k.jet_held.value)&&!bool(actor->get(k.jump_held.name));}
  else{
   bool braking=final&&offset.y<2&&speed>3&&(distance<.01||velocity.dot(direct)>std::max(2.,distance*.7)||velocity.slide(direct).length()>3);
   desired*=braking?.75:.28;state[k.jet_held.value]=!ceiling&&!bool(brain.get(k.jet_recharge.value,false))&&(braking||offset.y+1-full_velocity.y*.35>0);
  }
  if(offset.y>3){desired=(direct*.2-velocity*.035).limit_length(.22);Vector3 normal=movement[k.normal.value];if(grounded&&!b(state,k.jet_held.value)&&normal.y>.65&&normal.dot(direct)<-.035)desired=direct;}
  brain[k.travel_phase.value]="precision";
 }else{
  Vector3 normal=movement[k.normal.value];bool aligned=speed<1||velocity.normalized().dot(direct)>.65;
  double look=clamp(speed*.8,7,24);Vector3 probe=position+direct*look;Dictionary floor=c.ray(probe+up*24,probe-up*48);
  double rise=offset.y,ahead=distance;if(!floor.is_empty()){rise=v(floor,k.position.value).y-position.y;ahead=look;}
  double eta=clamp(ahead/std::max(speed,walk),.25,1.25),ballistic=full_velocity.y*eta-10*eta*eta;
  bool climb=rise>1||obstacle,launch=climb&&rise>ballistic+.7&&(speed>walk*.75||obstacle);
  desired=(direct*std::max(walk*1.15,speed)-velocity)*.12;
  if(grounded){desired=direct;state[k.ski.value]=ski(normal,direct,velocity,walk);state[k.jet_held.value]=launch&&!ceiling&&energy>capacity*.25;state[k.jump.value]=b(state,k.jet_held.value)&&!bool(actor->get(k.jump_held.name));brain[k.travel_phase.value]=b(state,k.ski.value)?"ski":"run_up";}
  else{
   double lift=20+2*(rise+.8-full_velocity.y*eta)/(eta*eta);desired=aligned?jet(full_velocity,direct,profile,k,lift):desired.limit_length(climb?.3:.65);state[k.ski.value]=true;
   bool turn=speed>3&&(velocity.dot(direct)<speed*.7||velocity.slide(direct).length()*std::min(distance/std::max(speed,walk),2.)>6);
   bool accelerate=!recharging&&aligned&&velocity.dot(direct)<n(profile,k.side_speed.value)*.85&&energy>capacity*.45&&rise < -2;
   state[k.jet_held.value]=!ceiling&&energy>3&&((climb&&rise+1>ballistic)||turn||accelerate);brain[k.travel_phase.value]=b(state,k.jet_held.value)?"climb":"coast";
  }
  if(b(state,k.jet_held.value)&&grounded)desired=desired.limit_length(.3);
 }
 if(final&&position.distance_to(goal)<double(ai->call(k.stop_radius.name,brain))){desired=-velocity.limit_length(1);state[k.ski.value]=false;state[k.jet_held.value]=false;state[k.jump.value]=false;brain[k.travel_phase.value]="arrive";}
 finish(c,id,brain,state,target,horizontal,desired);
}

void FPSBots::st_precision(Object *ai,int64_t id,Dictionary brain){
 const BotNames &k=names;Context c(ai,ray,k);Node3D *actor=c.actor(id);Dictionary state=c.players[id];
 if(bool(c.tribes->call(k.reroute_below_deck.name,id,brain)))return;
 Vector3 position=actor->get_position(),goal=brain[k.goal.value],target=goal;PackedVector3Array path=brain[k.path.value];int step=brain[k.step.value];
 if(step<path.size()){
  while(step<path.size()-1){Vector3 offset=path[step]-position;if(step>0&&(Vector2(offset.x,offset.z).length()>2.3||std::abs(offset.y)>2.8))break;++step;brain[k.step.value]=step;}
  target=path[step];
 }
 Vector3 offset=target-position,horizontal=flat(offset),full_velocity=actor->get(k.velocity.name),velocity=flat(full_velocity),direct=horizontal.normalized();double distance=horizontal.length();bool grounded=actor->call(k.is_supported.name);
 Object *routes=c.tribes->get(k.routes.name),*tactics=c.tribes->get(k.tactics.name),*avoidance=c.tribes->get(k.avoidance.name),*rules=c.mode->get(k.tribes.name);
 if(grounded&&offset.y < -3&&distance<5&&!c.ray(target+up*.3,Vector3(target.x,position.y+.3,target.z)).is_empty()){
  PackedVector3Array recovery=routes->call(k.path.name,position,goal,0,tactics->call(k.detours.name,id));
  if(!recovery.is_empty()){brain[k.path.value]=recovery;brain[k.step.value]=0;brain[k.route_at.value]=c.clock+12;return;}
 }
 Dictionary wall=avoidance->call(k.wall.name,position,position+direct*2);bool obstacle=!wall.is_empty(),ceiling=!c.ray(position+up*1.8,position+up*2.8).is_empty();
 Dictionary movement=actor->get(k.tribes_state.name),profile=rules->call(k.definition.name,id);double energy=n(movement,k.energy.value);
 recharge(brain,energy,n(profile,k.energy.value),grounded,offset,k);Vector3 desired=(horizontal*.65-velocity*.7).limit_length(1);bool rise=offset.y>1||obstacle;
 if(grounded){
  state[k.jet_held.value]=rise&&!ceiling&&!bool(brain.get(k.jet_recharge.value,false));state[k.jump.value]=b(state,k.jet_held.value)&&!bool(actor->get(k.jump_held.name));
  Vector3 normal=movement[k.normal.value];if(rise&&offset.y>3&&b(state,k.jet_held.value))desired=-velocity.limit_length(1);
  else if(rise&&!b(state,k.jet_held.value)&&normal.y>.65&&normal.dot(direct)<-.035)desired=direct;
 }else{
  desired*=.28;if(offset.y>3)desired=(-velocity*.3).limit_length(.12);
  state[k.jet_held.value]=!ceiling&&!bool(brain.get(k.jet_recharge.value,false))&&offset.y+1-full_velocity.y*.35>0;state[k.jump.value]=false;
 }
 state[k.ski.value]=velocity.length()>8&&offset.y<.6&&!obstacle&&distance>7&&ski(movement[k.normal.value],direct,velocity,n(profile,k.walk.value));
 if(step>=path.size()-1&&position.distance_to(goal)<double(ai->call(k.stop_radius.name,brain))){desired=-velocity.limit_length(1);state[k.ski.value]=false;state[k.jet_held.value]=false;}
 finish(c,id,brain,state,target,horizontal,desired);
}
