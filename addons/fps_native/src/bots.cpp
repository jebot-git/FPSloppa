#include "bots.h"
#include "bot_context.h"
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
using namespace godot::bot;
void FPSBots::_bind_methods(){
 ClassDB::bind_method(D_METHOD("st_route","ai","id","brain","recharging"),&FPSBots::st_route);
 ClassDB::bind_method(D_METHOD("st_precision","ai","id","brain"),&FPSBots::st_precision);
 ClassDB::bind_method(D_METHOD("perceive","ai","id","brain"),&FPSBots::perceive);
 ClassDB::bind_method(D_METHOD("combat","ai","id","brain","delta"),&FPSBots::combat);
 ClassDB::bind_method(D_METHOD("steer","ai","id","brain","delta"),&FPSBots::steer);
}
FPSBots::FPSBots(){ray.instantiate();ray->set_collision_mask(1);}
// Preserve candidate order, visibility gates and RNG calls. Mode-specific rules
// stay in their script callbacks; this kernel only batches the common decisions.
void FPSBots::perceive(Object *ai,int64_t id,Dictionary brain){
 const BotNames &k=names;Context c(ai,ray,k);Dictionary state=c.players[id];int64_t previous=brain[k.enemy.value],best=0;double score=-INFINITY;Array seen;brain[k.visible.value]=seen;
 Object *special=c.mode->get(k.special.name),*walkers=c.fortress->get(k.walkers.name);Dictionary frozen=special->get(k.frozen.name);
 Array ids=c.players.keys();const Vector3 eye=c.eye(id);
 for(int i=0;i<ids.size();++i){
  int64_t other=ids[i];if(other==id||!c.alive(other)||bool(c.mode->call(k.same_team.name,id,other))||frozen.has(other)||bool(c.fortress->call(k.cloaked.name,other)))continue;
  Dictionary other_state=c.players[other],disguise=other_state.get(k.tf_disguise.value,Dictionary());
  if(bool(c.fortress->call(k.enabled.name))&&disguise.get(k.team.value,-1)==state[k.team.value])continue;
  if(!bool(ai->call(k.can_engage.name,id,other)))continue;
  Vector3 target=c.target(other);double distance=eye.distance_to(target);if(distance>(c.kind=="st"?140:60))continue;
  Vector3 bearing=target-eye;
  if(other!=previous&&distance>6&&std::abs(Math::angle_difference(n(state,k.yaw.value),std::atan2(double(-bearing.x),double(-bearing.z))))>Math::deg_to_rad(110.))continue;
  if(!bool(ai->call(k.visible.name,id,other)))continue;
  seen.append(other);double value=35./(1+distance*.08)+(other==previous?8:0)+(bool(c.fortress->call(k.carrying.name,other))?12:0);
  if(c.kind=="st"){Object *st=c.mode->get(k.st.name),*offense=c.tribes->get(k.offense.name);if(int64_t(st->call(k.carried.name,other))>=0)value+=18;value+=double(offense->call(k.escort_priority.name,id,other));}
  if(c.kind=="tb"&&bool(walkers->call(k.mounted.name,other)))value+=30;
  if(distance<4)value+=20;
  value+=double(c.teamplay->call(k.focus_bonus.name,id,other));if(value>score){score=value;best=other;}
 }
 brain[k.enemy.value]=best;
 if(best!=0){
  if(previous!=best){if(int64_t(brain[k.remembered_enemy.value])!=best||c.clock-n(brain,k.last_seen_at.value)>.6){brain[k.seen_at.value]=c.clock;Object *aiming=brain[k.aiming.value];brain[k.reaction.value]=aiming->call(k.reaction.name);}brain[k.weapon_at.value]=0;if(double(c.teamplay->call(k.focus_bonus.name,id,best))>0)c.teamplay->call(k.count.name,"focus_choices");}
  brain[k.remembered_enemy.value]=best;brain[k.last_seen_at.value]=c.clock;brain[k.seen_position.value]=c.actor(best)->get_position();brain[k.memory_until.value]=c.clock+3;brain[k.observed_velocity.value]=c.actor(best)->get(k.velocity.name);
 }else if(previous!=0)brain[k.plan_at.value]=0;
 c.teamplay->call(k.observe.name,id,brain);ai->call(k.perceive_projectiles.name,id,brain);
}
// Produce ordinary player inputs; damage, ammo and physics remain authoritative
// in the existing arena systems. No persistent copies of mutable player state.
void FPSBots::combat(Object *ai,int64_t id,Dictionary brain,double delta){
 const BotNames &k=names;Context c(ai,ray,k);Dictionary state=c.players[id];state[k.fire.value]=false;state[k.alt_fire.value]=false;
 if(c.kind=="st"&&bool(c.tribes->call(k.combat.name,id,brain,delta)))return;
 Object *utility=c.defusal->get(k.utility.name);if(bool(utility->call(k.bot_combat.name,id,brain))||c.clock<n(brain,k.boost_until.value))return;
 if(bool(ai->call(k.translocator_input.name,id,brain,delta)))return;
 const Vector3 eye=c.eye(id);
 auto aim_input=[&](Vector3 point,double rate){
  Vector3 direction=(point-eye).normalized();double yaw=std::atan2(double(-direction.x),double(-direction.z)),pitch=std::asin(std::clamp(double(direction.y),-1.,1.));
  state[k.yaw.value]=Math::lerp_angle(n(state,k.yaw.value),yaw,rate);state[k.pitch.value]=Math::lerp(n(state,k.pitch.value),pitch,rate);
  return std::abs(Math::angle_difference(n(state,k.yaw.value),yaw))<.12&&std::abs(n(state,k.pitch.value)-pitch)<.12;
 };
 if(s(brain,k.goal_kind.value)=="destroy"&&c.kind=="as"){
  Object *assault=c.mode->get(k.assault.name);Array objectives=assault->get(k.objectives.name);int stage=assault->get(k.stage.name);
  if(bool(assault->call(k.can_advance.name,id))&&stage<objectives.size()){
   Dictionary objective=objectives[stage];Vector3 point=v(objective,k.position.value)+Vector3(0,1,0)*.85;
   if(eye.distance_to(point)<30&&(int64_t(brain[k.enemy.value])==0||!c.alive(brain[k.enemy.value])||eye.distance_to(c.target(brain[k.enemy.value]))>6)&&c.ray(eye,point).is_empty()){
    state[k.alt_fire.value]=false;state[k.weapon.value]=ai->call(k.choose_weapon.name,id,eye.distance_to(point));
    state[k.fire.value]=aim_input(point,1-std::exp(-10*delta))&&bool(ai->call(k.safe_shot.name,id,point,ai->call(k.explosive_weapon.name,id,state[k.weapon.value])));return;
   }
  }
 }
 int64_t enemy=brain[k.enemy.value];
 if(enemy!=0&&c.alive(enemy)){
  if(!bool(ai->call(k.can_engage.name,id,enemy))){brain[k.enemy.value]=0;brain[k.remembered_enemy.value]=0;brain[k.memory_until.value]=0;brain[k.plan_at.value]=0;return;}
  Vector3 point=c.target(enemy);
  if(n(brain,k.last_seen_at.value)>=0)point=v(brain,k.seen_position.value)+Vector3(0,1,0)*double(c.actor(enemy)->call(k.torso_height.name))+v(brain,k.observed_velocity.value)*std::clamp(c.clock-n(brain,k.last_seen_at.value),0.,.2)*.85;
  double distance=eye.distance_to(point);
  if(c.clock>=n(brain,k.weapon_at.value)||!bool(c.fortress->call(k.can_fire.name,id,state[k.weapon.value]))||!bool(ai->call(k.can_harm_target.name,id,enemy,state[k.weapon.value]))){state[k.weapon.value]=ai->call(k.choose_weapon.name,id,distance,enemy);brain[k.weapon_at.value]=c.clock+.2;}
  // ST carriers and committed cappers reserve jet energy even between weapon
  // selection ticks. Keep the newer ST rule identical to combat_reference.
  if(c.kind=="st"&&(bool(c.tribes->call(k.carrier.name,id))||(bool(brain.get(k.capture_preparing.value,false))&&s(brain,k.goal_key.value)=="st:flag"))){
   Object *offense=c.tribes->get(k.offense.name);if(!bool(offense->call(k.carrier_weapon.name,id,state[k.weapon.value])))return;
  }
  Dictionary data=c.fortress->call(k.weapon_data.name,id,state[k.weapon.value]);
  // Derive common traits once from the base definition, before alternate-fire
  // overrides. The script helpers perform these same read-only lookups again.
  const String rules=c.armory->call(k.effective.name);
  const bool melee=int(data.get(k.ammo.value,0))<0&&double(data.get(k.range.value,100))<4;
  const bool explosive=double(data.get(k.splash.value,0))>0||(rules=="doom"&&(int(state[k.weapon.value])==6||int(state[k.weapon.value])==8));
  bool alternate=ai->call(k.alternate_fire.name,id,distance,brain);
  if(alternate){data=data.duplicate();data.merge(data.get(k.alt.value,Dictionary()),true);}
  Object *aiming=brain[k.aiming.value];
  if(double(data.get(k.speed.value,0))>0){
   double flight=std::min(c.kind=="st"?2.:.8,distance/n(data,k.speed.value));Vector3 predicted=point+v(brain,k.observed_velocity.value)*flight*double(aiming->get(k.lead.name));
   Object *tribes=c.mode->get(k.tribes.name);if(bool(tribes->call(k.enabled.name)))predicted-=Vector3(c.actor(id)->get(k.velocity.name))*double(data.get(k.inherit.value,0))*flight;
   predicted.y+=.5*double(data.get(k.gravity.value,0))*flight*flight;if(c.ray(eye,predicted).is_empty())point=predicted;
  }
  double motion=std::max(double(v(brain,k.observed_velocity.value).length()),double(Vector3(c.actor(id)->get(k.velocity.name)).length()));
  if(!melee)point=aiming->call(k.point.name,eye,point,c.clock,motion);
  bool aligned=aim_input(point,1-std::exp(-double(aiming->get(k.response.name))*delta));
  bool safe=ai->call(k.safe_shot.name,id,point,explosive||double(data.get(k.splash.value,0))>0);
  if(rules=="quake"&&int(state[k.weapon.value])==8&&bool(c.actor(id)->get(k.in_water.name)))safe=false;
  state[k.fire.value]=aligned&&c.clock-n(brain,k.seen_at.value)>n(brain,k.reaction.value)&&distance<=double(data.get(k.range.value,100.))&&safe;
  if(alternate){state[k.alt_fire.value]=state[k.fire.value];if(rules!="cs16")state[k.fire.value]=false;}
  Object *combat=c.game->get(k.variant_combat.name);Dictionary charging=combat->get(k.charging.name);
  if(charging.has(id)){
   Dictionary charge=charging[id];if(!safe){state[k.input_blocked.value]=true;state[k.fire.value]=false;state[k.alt_fire.value]=false;}
   else if(n(charge,k.time.value)>.55&&(int(state[k.weapon.value])==1||int(state[k.weapon.value])==6)){state[k.fire.value]=false;state[k.alt_fire.value]=false;}
  }
 }
 Object *combat=c.game->get(k.variant_combat.name);Dictionary charging=combat->get(k.charging.name);if(int64_t(brain[k.enemy.value])==0&&charging.has(id))state[k.input_blocked.value]=true;
 if(bool(c.fortress->call(k.enabled.name))&&c.clock>=n(brain,k.action_at.value)){brain[k.action_at.value]=c.clock+.2;ai->call(k.class_action.name,id,brain);}
}
