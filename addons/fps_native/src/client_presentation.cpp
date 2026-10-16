#include <godot_cpp/variant/variant.hpp>
#include "client_presentation.h"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
#include <unordered_map>
using namespace godot;
namespace cqclient {
namespace {
// Cache keys once, rather than construct a Variant/String for each entity field.
#define K(text) ([]()->const String&{static const String key(text);return key;}())
#define V(text) ([]()->const Variant&{static const Variant key(K(text));return key;}())
#define D(d,k) (d)[V(k)]
Dictionary dict(const Dictionary&d,const String&k){return d.get(k,Dictionary());}
String entity(const char*prefix,const Variant&id){return String(prefix)+String::num_int64(int64_t(id));}
Dictionary make(std::initializer_list<std::pair<String,Variant>> fields){Dictionary d;for(const auto&field:fields)d[field.first]=field.second;return d;}
constexpr int PRIMARY[]={4,9,3,5},ADVANCED[]={1,10,12,11},THIRD[]={14,16,13,15};
bool keys(const Dictionary&d,std::initializer_list<const Variant*> list){for(auto k:list)if(!d.has(*k))return false;return true;}
}
Array project_frame(const Dictionary&frame,double origin,int64_t epoch,double duration){
 if(!std::isfinite(origin)||!std::isfinite(duration)||duration>=9223372036854775808.||duration< -9223372036854775808.||!keys(frame,{&V("mode"),&V("players"),&V("projectiles")}))return {};
 if(Variant(frame["mode"]).get_type()!=Variant::DICTIONARY||Variant(frame["players"]).get_type()!=Variant::DICTIONARY||Variant(frame["projectiles"]).get_type()!=Variant::DICTIONARY)return {};
 Dictionary mode_in=D(frame,"mode"),source=D(frame,"players");
 if(!keys(mode_in,{&V("scores"),&V("winner"),&V("time"),&V("lighting_time"),&V("zones"),&V("remaining"),&V("intermission")}))return {};
 static const String ROLES[]={"shocktroop","scout","medic","technician"};
 static const String UTILITY[][2]={{"jetpack","airstrike"},{"recon","recon_drone"},{"medical","healing_grenade"},{"engineering","turret"}};
 int winner=D(mode_in,"winner");if(winner< -2||winner>1)return {};
 double time=D(mode_in,"time");Dictionary locomotion,ack,ordnance;
 Dictionary mode=make({{K("kind"),"tdm"},{K("scores"),D(mode_in,"scores")},{K("bases"),Array()},{K("flags"),Array()},{K("hill"),Vector3()},{K("owner"),-1},{K("friendly_fire"),false},{K("announcer"),false},{K("weapon_rules"),"ut99"},{K("locomotion"),locomotion},{K("movement_ack"),ack},{K("ordnance"),ordnance},{K("cq_points"),make({{K("scores"),D(mode_in,"scores")},{K("winner"),winner}})},{K("class_mode"),make({{K("clock"),origin+time},{K("lighting_time"),D(mode_in,"lighting_time")}})}});
 Array players,shots,ids=source.keys();int64_t watermark=-1;
 // Build vehicle seating once per player instead of scanning every rider per truck.
 std::unordered_map<int64_t,std::pair<Array,Array>> seats;
 for(int i=0;i<ids.size();++i){
  Variant id=ids[i];if(Variant(source[id]).get_type()!=Variant::DICTIONARY)return {};Dictionary p=source[id];
  if(!keys(p,{&V("class"),&V("owned"),&V("clips"),&V("spotted"),&V("designation"),&V("life"),&V("position"),&V("velocity"),&V("weapon"),&V("physical"),&V("height"),&V("grounded"),&V("stamina"),&V("jump_ack"),&V("jetpack_ack"),&V("fire_ack"),&V("team"),&V("nvg"),&V("armor"),&V("dead"),&V("ammo"),&V("kills"),&V("deaths"),&V("respawn_at"),&V("invulnerable"),&V("cooldown"),&V("xr"),&V("incapacitated"),&V("inject_progress"),&V("grenades"),&V("grenade_selected"),&V("grenade_primed"),&V("grenade_offhand"),&V("lock_vehicle"),&V("lock_elapsed"),&V("charge_at")}))return {};
  Dictionary c=D(p,"class");if(!keys(c,{&V("role"),&V("next"),&V("equipped_t2"),&V("xp"),&V("primary_t2"),&V("secondary_t2"),&V("utility_t2"),&V("blind_until"),&V("cloak_until"),&V("cloak_ready"),&V("box_ready"),&V("drone_ready"),&V("strike_ready"),&V("turret_ready")}))return {};
  int role=D(c,"role"),next=D(c,"next");Array xp_in=D(c,"xp"),spotted=D(p,"spotted");PackedInt32Array clips_in=D(p,"clips");
  if(role<0||role>3||next<0||next>3||xp_in.size()!=4||spotted.size()!=2||clips_in.size()!=17)return {};
  Dictionary xp,primary,secondary,utility;
  for(int j=0;j<4;++j){int bit=1<<j;xp[ROLES[j]]=xp_in[j];primary[ROLES[j]]=(int(p.get(K("primary_t3"),0))&bit)?THIRD[j]:(int(D(c,"primary_t2"))&bit)?ADVANCED[j]:PRIMARY[j];secondary[ROLES[j]]=(int(D(c,"secondary_t2"))&bit)?0:j==1?8:2;utility[ROLES[j]]=UTILITY[j][bool(int(D(c,"utility_t2"))&bit)];}
  Dictionary state=make({{K("team"),D(p,"team")},{K("squad"),p.get(K("squad"),-1)},{K("combat_until"),origin+double(p.get(K("combat_until"),0.))},{K("class"),ROLES[role]},{K("next"),ROLES[next]},{K("xp"),xp},{K("nv"),D(p,"nvg")},{K("nb"),origin+double(D(c,"blind_until"))},{K("cloak_until"),origin+double(D(c,"cloak_until"))},{K("cloak_ready"),origin+double(D(c,"cloak_ready"))},{K("dispenser_ready"),origin+double(D(c,"box_ready"))},{K("drone_ready"),origin+double(D(c,"drone_ready"))},{K("airstrike_ready"),origin+double(D(c,"strike_ready"))},{K("turret_ready"),origin+double(D(c,"turret_ready"))},{K("primary_choices"),primary},{K("secondary_choices"),secondary},{K("utility_choices"),utility},{K("equipped_utility"),UTILITY[role][bool(D(c,"equipped_t2"))]},{K("weapon_held"),p.get(K("weapon_held"),true)}});
  Dictionary clips;for(int j=0;j<17;++j)clips[j]=clips_in[j];
  Dictionary mag=make({{K("serial"),D(p,"life")},{K("weapon"),D(p,"weapon")},{K("clips"),clips},{K("physical"),D(p,"physical")},{K("reloading"),p.get(K("reloading"),-1)},{K("reload_at"),origin+double(p.get(K("reload_at"),0.))},{K("cycling"),p.get(K("cycling"),-1)},{K("cycle_at"),origin+double(p.get(K("cycle_at"),0.))}});
  Dictionary lock,charge;int64_t target=D(p,"lock_vehicle");double charged=D(p,"charge_at");if(target)lock=make({{K("ready"),double(D(p,"lock_elapsed"))>=1.5},{K("elapsed"),D(p,"lock_elapsed")},{K("target"),String::num_int64(target)},{K("life"),D(p,"life")}});if(charged>0)charge[K("at")]=origin+charged;
  mode[entity("cp:",id)]=make({{K("state"),state},{K("mag"),mag},{K("spot"),Array::make(origin+double(spotted[0]),origin+double(spotted[1]))},{K("lock"),lock},{K("charge"),charge}});
  if(bool(D(p,"incapacitated")))mode[entity("cd:",id)]=make({{K("remaining"),D(p,"bleed_remaining")},{K("attacker"),0},{K("weapon"),"INJURY"}});
  if(double(D(p,"inject_progress"))>0)mode[entity("ci:",id)]=make({{K("medic"),D(p,"injector")},{K("progress"),D(p,"inject_progress")},{K("touched"),origin+time}});
  Dictionary designation=D(p,"designation");if(bool(D(designation,"active")))mode[entity("cl:",id)]=make({{K("start"),D(designation,"start")},{K("position"),D(designation,"position")},{K("direction"),D(designation,"direction")},{K("until"),origin+double(D(designation,"until"))},{K("team"),D(p,"team")},{K("life"),D(p,"life")}});
  locomotion[id]=make({{K("incapacitated"),D(p,"incapacitated")},{K("height"),D(p,"height")},{K("grounded"),D(p,"grounded")},{K("cs16_stamina"),D(p,"stamina")},{K("jetpack"),dict(p,K("jetpack")).duplicate()},{K("jump_ack"),D(p,"jump_ack")},{K("jetpack_ack"),D(p,"jetpack_ack")},{K("fire_ack"),D(p,"fire_ack")}});ack[id]=D(p,"last_seq");
  Array ammo;PackedInt32Array packed_ammo=D(p,"ammo");for(int j=0;j<packed_ammo.size();++j)ammo.append(packed_ammo[j]);
  players.append(Array::make(id,D(p,"position"),D(p,"velocity"),D(p,"yaw"),D(p,"pitch"),D(p,"hp"),D(p,"armor"),D(p,"dead"),D(p,"weapon"),ammo,D(p,"owned"),D(p,"kills"),D(p,"deaths"),0,D(p,"life"),std::max(0.,double(D(p,"respawn_at"))-time),double(D(p,"invulnerable"))>time,D(p,"cooldown"),D(p,"xr"),0.,p.get(K("staging"),false),Vector2()));
  bool advanced=D(c,"equipped_t2");int grenade_kind=role==2&&advanced?3:0;
  mode[entity("cg:",id)]=Array::make(Array::make(role==0?int(D(p,"grenades")):0,0,0,role==2?int(D(p,"grenades")):0),bool(D(p,"grenade_selected"))?grenade_kind:-1,D(p,"grenade_primed"),D(p,"grenade_offhand"),grenade_kind);
  int seat=p.get(K("vehicle_seat"),-1);if(seat>=0&&seat<8&&p.has(K("vehicle"))){int64_t vehicle=D(p,"vehicle");auto found=seats.find(vehicle);if(found==seats.end()){Array occupants,lives;for(int j=0;j<8;++j){occupants.append(0);lives.append(0);}found=seats.emplace(vehicle,std::make_pair(occupants,lives)).first;}found->second.first[seat]=id;found->second.second[seat]=D(p,"life");}
 }
 Array zones=D(mode_in,"zones");for(int i=0;i<zones.size();++i)mode[entity("cqo:",i)]=zones[i];
 Dictionary boxes=dict(frame,K("boxes"));Array keys_in=boxes.keys();for(int i=0;i<keys_in.size();++i){Variant key=keys_in[i];Dictionary b=boxes[key];mode[entity("cb:",key)]=make({{K("owner"),D(b,"owner")},{K("team"),D(b,"team")},{K("kind"),bool(D(b,"health"))?"health":"ammo"},{K("position"),D(b,"position")},{K("remaining"),D(b,"remaining")}});}
 Dictionary vehicles=dict(frame,K("vehicles"));keys_in=vehicles.keys();const String kinds[]={"rocket","light","heavy","transport","bike"};
 for(int i=0;i<keys_in.size();++i){Variant key=keys_in[i];Dictionary v=Dictionary(vehicles[key]).duplicate();int kind=D(v,"kind");if(kind<0||kind>=5)return {};D(v,"kind")=kinds[kind];v[K("left")]=D(v,"remaining");for(const auto&k:{K("next"),K("reload_at"),K("shot_at")})v[k]=origin+double(v[k]);v[K("spawn")]=D(v,"position");v[K("speed")]=Vector3(D(v,"velocity")).length();
  if(kind==3){Array occupants,lives;auto found=seats.find(int64_t(D(v,"index")));if(found!=seats.end()){occupants=found->second.first;lives=found->second.second;}else for(int j=0;j<8;++j){occupants.append(0);lives.append(0);}v[K("seats")]=occupants;v[K("seat_lives")]=lives;}mode[entity("ctk:",key)]=v;
 }
 for(int section=0;section<3;++section){const String names[]={K("turrets"),K("fields"),K("flights")};Dictionary entities=dict(frame,names[section]);keys_in=entities.keys();for(int i=0;i<keys_in.size();++i){Variant key=keys_in[i];Dictionary row=Dictionary(entities[key]).duplicate();const char*prefix="";
  if(section==0){row[K("fire_at")]=origin+double(D(row,"shot_at"))+1.5;D(row,"shot_at")=origin+double(D(row,"shot_at"));prefix="ctu:";}
  else if(section==1){D(row,"until")=origin+double(D(row,"until"));D(row,"hit_at")=origin+double(D(row,"hit_at"));prefix="chf:";}
  else{for(const auto&k:{K("at"),K("until"),K("impact_at")})row[k]=origin+double(row[k]);prefix=bool(D(row,"strike"))?"cas:":"crd:";}mode[entity(prefix,key)]=row;
 }}
 Dictionary grenades=dict(frame,K("grenades"));keys_in=grenades.keys();for(int i=0;i<keys_in.size();++i){Variant key=keys_in[i];Dictionary g=grenades[key];mode[entity("ch:",key)]=Array::make(key,D(g,"kind"),D(g,"owner"),D(g,"position"),D(g,"velocity"),D(g,"age"),false);}
 Dictionary projectiles=D(frame,"projectiles");keys_in=projectiles.keys();for(int i=0;i<keys_in.size();++i){Variant key=keys_in[i];Dictionary p=projectiles[key];Vector3 direction=Vector3(D(p,"velocity")).normalized();shots.append(Array::make(key,D(p,"position"),D(p,"owner"),D(p,"weapon"),direction,std::atan2(-double(direction.x),-double(direction.z)),std::asin(std::clamp(double(direction.y),-1.,1.))));watermark=std::max(watermark,int64_t(key));Dictionary extra=make({{K("cq_team"),D(p,"team")},{K("owner_life"),D(p,"life")}}),definition;
  bool battery=int(D(p,"weapon"))==5&&Math::is_equal_approx(double(D(p,"gravity")),20.)&&double(D(p,"radius"))>.1;
  if(battery){extra[K("battery_shot")]=true;definition=make({{K("kind"),"tribes_mortar"},{K("gravity"),D(p,"gravity")},{K("radius"),D(p,"radius")},{K("arm"),D(p,"arm")},{K("fuse"),90.},{K("splash"),152.},{K("blast_radius"),30.},{K("speed"),std::sqrt(100000.)},{K("damage"),152.},{K("bounce"),0.},{K("guided"),false},{K("cq_effect"),"ordnance"}});}
  Dictionary row=make({{K("velocity"),D(p,"velocity")},{K("life"),D(p,"remaining")},{K("stuck"),D(p,"stuck")},{K("extra"),extra}});if(battery)row[K("definition")]=definition;ordnance[key]=row;
 }
 String message=winner==-2?"":winner<0?"DRAW":winner==0?"RED WINS":"BLUE WINS";
 return Array::make(players,PackedByteArray(),D(mode_in,"remaining"),D(mode_in,"intermission"),message,200,int64_t(duration),shots,Array(),epoch,mode,Dictionary(),origin+time,watermark);
}
}
