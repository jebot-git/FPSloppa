#include "bots.h"
#include "bot_context.h"
using namespace godot;
using namespace godot::bot;
// Synchronous counterpart of steer_reference. Navigation keeps ownership of
// authored links, hazard tests and route recovery; Tribes retains its own steering.
void FPSBots::steer(Object *ai,int64_t id,Dictionary brain,double delta){
 const BotNames &k=names;Context c(ai,ray,k);if(c.kind=="st"){c.tribes->call(k.steer.name,id,brain);return;}
 Dictionary state=c.players[id];Node3D *actor=c.actor(id);const Vector3 position=actor->get_position(),velocity=actor->get(k.velocity.name),up(0,1,0);
 auto supported=[&](){return bool(actor->call(k.is_supported.name));};
 const bool in_water=actor->get(k.in_water.name),jump_held=actor->get(k.jump_held.name);
 state[k.jump.value]=false;state[k.swim.value]=Vector3();state[k.slow.value]=false;state[k.crouch.value]=false;state[k.prone.value]=false;
 Dictionary avoid=brain[k.avoid.value];
 if(!s(brain,k.goal_key.value).is_empty()&&one_of(s(brain,k.goal_kind.value),{"roam","search","explore"})&&position.distance_to(v(brain,k.goal.value))<(s(brain,k.goal_kind.value)=="explore"?.5:1.5)){avoid[brain[k.goal_key.value]]=c.clock+12;brain[k.plan_at.value]=0;}
 Vector3 travel=v(brain,k.goal.value)-position;double remaining=travel.length();
 bool at_goal=remaining<double(ai->call(k.stop_radius.name,brain))&&(b(brain,k.hold.value)||one_of(s(brain,k.goal_kind.value),{"item","objective","capture"}));
 if(one_of(s(brain,k.goal_kind.value),{"heal","repair","destroy","escort"})&&at_goal)at_goal=c.ray(c.eye(id),v(brain,k.goal.value)+up).is_empty();
 bool riding_lift=false;PackedVector3Array path=brain[k.path.value];int step=brain[k.step.value];
 if(step<path.size()){
  while(step<path.size()-1){Vector3 waypoint=path[step];bool reached=position.distance_to(waypoint)<.65;
   if(step==0||in_water)reached=reached||(Vector2(position.x-waypoint.x,position.z-waypoint.z).length()<.65&&std::abs(position.y-waypoint.y)<2.5);
   if(!reached)break;
   ++step;
  }
  brain[k.step.value]=step;travel=path[step]-position;Dictionary link=c.navigation->call(k.active_link.name,position,path[step]);
  if(link.is_empty())for(int index=step+1;index<std::min(int(path.size()),step+5);++index){Dictionary upcoming=c.navigation->call(k.active_link.name,position,path[index]);if(String(upcoming.get(k.kind.value,""))=="lift"){link=upcoming;break;}}
  if(!link.is_empty()){
   String kind=s(link,k.kind.value);travel=(one_of(kind,{"jump","drop"})?v(link,k.end.value):v(link,k.entry.value))-position;
   if(kind=="drop"){brain[k.drop_end.value]=link[k.end.value];brain[k.drop_until.value]=c.clock+1.5;brain[k.plan_at.value]=c.clock+1.5;}
   if(one_of(kind,{"pad","push_chain"})&&velocity.length()>10){brain[k.pad_chain.value]=kind=="push_chain";brain[k.pad_end.value]=link[k.end.value];brain[k.pad_until.value]=c.clock+8;brain[k.plan_at.value]=c.clock+8;}
   if(kind=="jump"&&supported()&&!jump_held)state[k.jump.value]=true;
   if(kind=="lift")brain[k.lift_link.value]=link;
  }
 }
 // Preserve moving-platform commitments before ordinary local avoidance.
 Dictionary lift_link=brain[k.lift_link.value];
 if(!lift_link.is_empty()){
  Dictionary lift=lift_link[k.lift.value];Node3D *node=Object::cast_to<Node3D>(lift[k.node.value]);Vector3 platform=v(lift_link,k.entry.value)+up*(node->get_position().y-n(lift,k.base.value));
  if(position.y<v(lift_link,k.deck_end.value).y-.35){travel=platform-position;if(Vector2(travel.x,travel.z).length()<.35||platform.y>position.y+.55)travel=Vector3();riding_lift=true;}
  else{travel=v(lift_link,k.end.value)-position;if(position.distance_to(v(lift_link,k.end.value))<.5){brain[k.lift_link.value]=Dictionary();brain[k.plan_at.value]=0;}else riding_lift=true;}
 }
 if(at_goal)travel=Vector3();
 if(at_goal||riding_lift){brain[k.progress_at.value]=c.clock;brain[k.progress_position.value]=position;}
 else if(c.clock-n(brain,k.progress_at.value)>2.){
  if(position.distance_to(v(brain,k.progress_position.value))<.75){
   brain[k.recover_direction.value]=ai->call(k.recovery_direction.name,position,travel,id,brain);brain[k.recover_prone.value]=!c.ray(position+up*.1,position+up*1.1).is_empty();brain[k.recover_until.value]=c.clock+.65;
   avoid[brain[k.goal_key.value]]=c.clock+3;brain[k.plan_at.value]=0;brain[k.path.value]=PackedVector3Array();
  }
  brain[k.progress_at.value]=c.clock;brain[k.progress_position.value]=position;
 }
 Vector3 desired(travel.x,0,travel.z);if(desired.length()>.1)desired=desired.normalized();
 if(int64_t(brain[k.enemy.value])!=0&&s(brain,k.goal_kind.value)=="enemy"){
  double distance=position.distance_to(c.actor(brain[k.enemy.value])->get_position()),ideal=ai->call(k.ideal_range.name,id,state[k.weapon.value]);
  if(distance<ideal*.65)desired=-desired;
  else if(distance<ideal*1.25){if(c.clock>=n(brain,k.strafe_at.value)){brain[k.strafe_at.value]=c.clock+UtilityFunctions::randf_range(.55,1.6);brain[k.strafe.value]=UtilityFunctions::randf()>.5?1.:-1.;}desired=desired.cross(up)*n(brain,k.strafe.value);}
 }
 if(int64_t(brain[k.enemy.value])==0&&!one_of(s(brain,k.goal_kind.value),{"heal","repair","destroy"})&&desired.length()>.1)state[k.yaw.value]=Math::lerp_angle(n(state,k.yaw.value),std::atan2(double(-desired.x),double(-desired.z)),std::min(1.,delta*10));
 if(at_goal&&int64_t(brain[k.enemy.value])==0&&one_of(s(brain,k.goal_kind.value),{"guard","ambush"})){ai->call(k.aim.name,id,v(brain,k.watch.value)+up,1-std::exp(-6*delta));state[k.crouch.value]=s(brain,k.goal_kind.value)=="ambush";}
 if(at_goal&&int64_t(brain[k.enemy.value])==0&&bool(c.defusal->call(k.enabled.name))&&s(brain,k.goal_key.value).begins_with("de:")&&s(brain,k.goal_kind.value)=="defend"&&brain.has(k.de_watch.value))ai->call(k.aim.name,id,v(brain,k.de_watch.value)+up,1-std::exp(-6*delta));
 if(!riding_lift&&c.clock<n(brain,k.dodge_until.value)){desired=v(brain,k.dodge.value);at_goal=false;}
 if(!riding_lift&&c.clock<n(brain,k.recover_until.value)){desired=v(brain,k.recover_direction.value);at_goal=false;}
 if(!at_goal&&!riding_lift){
  Array friends=c.fighters.keys();for(int i=0;i<friends.size();++i){int64_t peer=friends[i];if(peer==id||!c.alive(peer)||!bool(c.mode->call(k.same_team.name,id,peer)))continue;
   Vector3 offset=position-c.actor(peer)->get_position();offset.y=0;if(offset.length()>.05&&offset.length()<1.2)desired+=offset.normalized()*(1.2-offset.length())*.8;
  }
  desired=desired.limit_length(1);
 }
 // World probes use the same mask and endpoints as navigation.ray.
 if(in_water){
  Vector3 stroke=Vector3(desired.x,std::clamp(double(travel.y)*.8,-1.,1.),desired.z).limit_length(1);if(bool(actor->get(k.underwater.name))&&travel.y>=-.2)stroke.y=std::max(.6,double(stroke.y));
  state[k.swim.value]=Basis(up,-n(state,k.yaw.value)).xform(stroke);state[k.jump.value]=travel.y>.25&&!jump_held;
 }else if(desired.length()>.1){
  Vector3 forward=desired.normalized(),look=position+forward*std::clamp(double(Vector2(travel.x,travel.z).length()),.35,1.);
  bool low=!c.ray(position+up*.4,look+up*.4).is_empty(),middle=!c.ray(position+up*.9,look+up*.9).is_empty(),high=!c.ray(position+up*1.55,look+up*1.55).is_empty();
  if(high&&!middle)state[k.crouch.value]=true;else if(middle&&!low)state[k.prone.value]=true;
  Dictionary landing=c.ray(look+up*.6,look-up*2.2);bool safe_floor=!landing.is_empty()&&v(landing,k.normal.value).y>.65&&!bool(c.navigation->call(k.hazardous.name,landing[k.position.value]));
  if(supported()){
   if(!safe_floor){Vector3 beyond=position+forward*3.;Dictionary floor=c.ray(beyond+up,beyond-up*1.2);
    if(!floor.is_empty()&&v(floor,k.normal.value).y>.7&&!bool(c.navigation->call(k.hazardous.name,floor[k.position.value]))&&bool(c.navigation->call(k.jump_clear.name,position,floor[k.position.value],9.4*double(actor->get(k.speed_multiplier.name)))))state[k.jump.value]=!jump_held;
    else{desired=Vector3();brain[k.stuck.value]=n(brain,k.stuck.value)+delta;}
   }else if(low&&!middle&&bool(c.navigation->call(k.jump_clear.name,position,position+forward*2.5,9.4*double(actor->get(k.speed_multiplier.name)))))state[k.jump.value]=!jump_held;
   else if(!high&&!middle&&!low&&!riding_lift&&remaining>7&&travel.length()>5&&!b(state,k.crouch.value)&&!b(state,k.prone.value)&&!one_of(s(brain,k.goal_kind.value),{"cover","defend","heal","repair","guard","ambush"})){
    Vector3 ahead=position+forward*4.;Dictionary floor=c.ray(ahead+up*.6,ahead-up);
    if(!floor.is_empty()&&!bool(c.navigation->call(k.hazardous.name,floor[k.position.value]))&&bool(c.navigation->call(k.jump_clear.name,position,floor[k.position.value],9.4*double(actor->get(k.speed_multiplier.name)))))state[k.jump.value]=!jump_held;
   }
  }
  if(low&&middle&&!b(state,k.prone.value)){Vector3 side=forward.cross(up)*(id%2==0?1:-1);if(c.ray(position+up,position+side+up).is_empty())desired=(forward+side).normalized();}
  if(!supported()){Vector3 horizontal(velocity.x,0,velocity.z),lateral=horizontal-forward*horizontal.dot(forward);desired=(desired-lateral*.09).limit_length(1);}
  else if(travel.length()<2&&remaining>2)desired*=.6;
 }
 if(at_goal&&s(brain,k.goal_kind.value)=="cover")state[k.crouch.value]=true;
 if(at_goal&&s(brain,k.goal_kind.value)=="defend"&&int64_t(brain[k.enemy.value])!=0){state[k.crouch.value]=true;if(String(state.get(k.tf_class.value,""))=="sniper"&&position.distance_to(v(brain,k.seen_position.value))>20){state[k.prone.value]=true;state[k.crouch.value]=false;}}
 // Weapon-assisted jumps, drop links, recovery and pad chains override travel
 // in the same order as the script path.
 if(b(brain,k.rocket_route.value)&&supported()&&n(state,k.cooldown.value)<=0){String kind=ai->call(k.boost_route.name,id,brain,brain[k.goal.value]);if(!kind.is_empty()){
  brain[k.boost_kind.value]=kind;brain[k.boost_release_at.value]=c.clock+(kind=="hammer"?1.55:0.);brain[k.boost_until.value]=n(brain,k.boost_release_at.value)+.35;brain[k.boost_at.value]=c.clock+6;brain[k.boost_shots.value]=state[k.shots.value];brain[k.plan_at.value]=c.clock+3;brain[k.rocket_route.value]=false;
 }}
 if(c.clock<n(brain,k.boost_until.value)){
  state[k.alt_fire.value]=false;state[k.crouch.value]=false;state[k.prone.value]=false;
  if(s(brain,k.boost_kind.value)=="hammer"){
   state[k.weapon.value]=0;state[k.pitch.value]=-3.14159265358979323846/2;desired=Vector3();state[k.jump.value]=false;
   if(!bool(ai->call(k.boost_safe.name,id,brain,"hammer"))||(state[k.shots.value]==brain[k.boost_shots.value]&&c.clock<n(brain,k.boost_release_at.value)&&!supported())){state[k.input_blocked.value]=true;state[k.fire.value]=false;brain[k.boost_until.value]=0;brain[k.plan_at.value]=0;}
   else{state[k.fire.value]=c.clock<n(brain,k.boost_release_at.value)&&state[k.shots.value]==brain[k.boost_shots.value];if(!b(state,k.fire.value)&&state[k.shots.value]==brain[k.boost_shots.value])state[k.jump.value]=supported()&&!jump_held;}
  }else{state[k.weapon.value]=6;state[k.pitch.value]=-1.45;state[k.fire.value]=state[k.shots.value]==brain[k.boost_shots.value];state[k.jump.value]=b(state,k.fire.value)&&supported()&&!jump_held;desired*=.2;}
 }else if(c.clock<n(brain,k.boost_at.value)-2&&!supported()){Vector3 horizontal(velocity.x,0,velocity.z),offset(v(brain,k.goal.value).x-position.x,0,v(brain,k.goal.value).z-position.z);desired=(offset*.7-horizontal*.18).limit_length(1);}
 if(c.clock<n(brain,k.drop_until.value)){
  Vector3 offset(v(brain,k.drop_end.value).x-position.x,0,v(brain,k.drop_end.value).z-position.z),horizontal(velocity.x,0,velocity.z);desired=(offset*.9-horizontal*.18).limit_length(.6);state[k.jump.value]=false;
  if(supported()&&position.y<v(brain,k.drop_end.value).y+.5){brain[k.drop_until.value]=0;brain[k.plan_at.value]=0;}
 }
 if(c.clock<n(brain,k.recover_until.value)&&!v(brain,k.recover_direction.value).is_zero_approx()){desired=v(brain,k.recover_direction.value);if(b(brain,k.recover_jump.value)&&supported())state[k.jump.value]=!jump_held;}
 if(c.clock<n(brain,k.recover_until.value)&&b(brain,k.recover_prone.value)){state[k.prone.value]=true;state[k.crouch.value]=false;state[k.jump.value]=false;}
 if(b(brain,k.recover_prone.value)||double(actor->get(k.collision_height.name))<1.6){
  Dictionary ceiling=c.ray(position+up*.1,position+up*1.7);
  if(!ceiling.is_empty()&&v(ceiling,k.normal.value).y<-.5){double clearance=v(ceiling,k.position.value).y-position.y;state[k.prone.value]=clearance<1.3;state[k.crouch.value]=!b(state,k.prone.value);state[k.jump.value]=false;}else brain[k.recover_prone.value]=false;
 }
 if(c.clock<n(brain,k.pad_until.value)){
  Vector3 horizontal(velocity.x,0,velocity.z),offset(v(brain,k.pad_end.value).x-position.x,0,v(brain,k.pad_end.value).z-position.z);
  desired=velocity.y>0&&(b(brain,k.pad_chain.value)||position.y<v(brain,k.pad_end.value).y+.35)?Vector3():(offset*.9-horizontal*.2).limit_length(1);
  if(supported()&&position.distance_to(v(brain,k.pad_end.value))<1.){brain[k.pad_until.value]=0;brain[k.plan_at.value]=0;}
 }
 desired=c.titanball->call(k.steering.name,id,brain,desired);Vector3 local=Basis(up,-n(state,k.yaw.value)).xform(desired);state[k.move.value]=Vector2(local.x,local.z).limit_length(1);
 if(!at_goal&&!riding_lift&&travel.length()>.1&&position.distance_to(v(brain,k.last.value))<delta*.5)brain[k.stuck.value]=n(brain,k.stuck.value)+delta;
 else if(position.distance_to(v(brain,k.last.value))>delta)brain[k.stuck.value]=std::max(0.,n(brain,k.stuck.value)-delta*2);else brain[k.stuck.value]=0;
 if(riding_lift||c.clock<n(brain,k.boost_until.value)){brain[k.stuck.value]=0;brain[k.plan_at.value]=c.clock+.8;}
 if(n(brain,k.stuck.value)>1.5){avoid[brain[k.goal_key.value]]=c.clock+6;brain[k.plan_at.value]=0;brain[k.stuck.value]=0;brain[k.path.value]=PackedVector3Array();}
 if(at_goal&&one_of(s(brain,k.goal_kind.value),{"item","objective","capture","checkpoint"}))brain[k.plan_at.value]=std::min(n(brain,k.plan_at.value),c.clock+.2);
 brain[k.last.value]=position;
}
