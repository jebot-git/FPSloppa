#include <godot_cpp/variant/variant.hpp>
#include "client_frame.h"
#include "authority_protocol.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <cmath>
#include <cstring>
#include <unordered_set>
using namespace godot;
namespace cqclient {
namespace {
struct Wire {
 const uint8_t *p;
 uint64_t u(size_t at,int n)const{uint64_t v=0;for(int i=0;i<n;++i)v|=uint64_t(p[at+i])<<(8*i);return v;}
 int64_t s(size_t at,int n)const{uint64_t v=u(at,n);if(n<8&&(v&(uint64_t(1)<<(n*8-1))))v|=(~uint64_t(0))<<(n*8);int64_t out;std::memcpy(&out,&v,8);return out;}
 double f(size_t at)const{uint32_t bits=uint32_t(u(at,4));float v;std::memcpy(&v,&bits,4);return v;}
 Vector3 v(size_t at)const{return Vector3(f(at),f(at+4),f(at+8));}
 Transform3D t(size_t at)const{return Transform3D(Basis(v(at),v(at+12),v(at+24)),v(at+36));}
};
enum Type {U8,S8,U16,S16,U32,S32,U64,S64,F,V,B};
struct Field {const char*name;size_t at;Type type;};
Dictionary fields(const Wire&w,size_t at,std::initializer_list<Field> list){Dictionary d;for(auto&f:list){size_t a=at+f.at;Variant x;switch(f.type){case U8:x=int64_t(w.u(a,1));break;case S8:x=w.s(a,1);break;case U16:x=int64_t(w.u(a,2));break;case S16:x=w.s(a,2);break;case U32:x=int64_t(w.u(a,4));break;case S32:x=w.s(a,4);break;case U64:case S64:x=w.s(a,8);break;case F:x=w.f(a);break;case V:x=w.v(a);break;case B:x=bool(w.u(a,1));break;}d[f.name]=x;}return d;}
}
Dictionary decode_frame(const PackedByteArray&bytes,bool validated){
 if(!validated&&!cqauthority::validate_frame(bytes.ptr(),bytes.size()))return {};
 Wire w{bytes.ptr()};int version=w.p[3]-'0';size_t count=w.u(12,2),at=14;
 Dictionary out,players,projectiles;out["tick"]=w.s(4,8);out["version"]=version;out["players"]=players;out["projectiles"]=projectiles;
 for(size_t i=0;i<count;++i,at+=104){
  int64_t id=w.s(at,8);Dictionary p=fields(w,at,{{"life",8,U32},{"team",12,U8},{"dead",13,B},{"weapon",14,U8},{"grounded",15,B},{"position",16,V},{"velocity",28,V},{"yaw",40,F},{"pitch",44,F},{"height",48,F},{"hp",52,F},{"last_seq",56,S64},{"shots",64,U64}});
  PackedInt32Array ammo,clips;for(int j=0;j<4;++j)ammo.append(w.u(at+72+j*2,2));for(int j=0;j<17;++j)clips.append(j<12?w.u(at+80+j*2,2):0);
  p["ammo"]=ammo;p["clips"]=clips;p["xr"]=Dictionary();p["physical"]=Dictionary();players[id]=p;
 }
 if(version==1)return out;
 std::unordered_set<uint16_t> sections;
 while(at<size_t(bytes.size())){
  int kind=w.u(at,2);size_t length=w.u(at+2,4);at+=6;size_t end=at+length,rows=w.u(at,2);at+=2;
  if(!sections.insert(uint16_t(kind)).second)return {};
  if(kind>16){at=end;continue;}
  if(kind==6){
   Dictionary mode=fields(w,at,{{"winner",0,S8},{"time",5,F},{"light_fraction",9,F},{"epoch",13,U32},{"intermission",17,F},{"lighting_time",21,F},{"remaining",25,F}});
   Array scores;scores.append(int64_t(w.u(at+1,2)));scores.append(int64_t(w.u(at+3,2)));mode["scores"]=scores;Array zones;at+=29;
   for(size_t i=0;i<rows;++i,at+=30){Dictionary z=fields(w,at,{{"position",0,V},{"radius",12,F},{"owner",16,S8},{"credit",25,F},{"contested",29,B}});Array progress;progress.append(w.f(at+17));progress.append(w.f(at+21));z["progress"]=progress;zones.append(z);}mode["zones"]=zones;out["mode"]=mode;continue;
  }
  static constexpr size_t sizes[]={0,0,42,67,41,147,0,36,47,98,74,79,54,63,83,17,27};
  static constexpr const char*names[]={"","","","","","","","boxes","fields","vehicles","turrets","flights","grenades","events"};
  Dictionary entities;if(kind==3)entities=projectiles;else if(kind>=7&&kind<=13){out[names[kind]]=entities;}
  for(size_t i=0;i<rows;++i){
   size_t size=sizes[kind];int64_t key=w.s(at,8);Dictionary p;if(kind==1||kind==2||kind==4||kind==5||kind>=14)p=players[key];
   if(kind==1){
    bool offhand=w.p[at+12]&2;size=offhand?257:209;Dictionary pose;pose["left_handed"]=bool(w.p[at+12]&1);pose["height"]=w.f(at+13);
    const char*keys[]={"head","left","right","weapon","offhand_weapon"};for(int j=0;j<(offhand?5:4);++j)pose[keys[j]]=w.t(at+17+j*48);p["xr"]=pose;
   }else if(kind==2){
    int weapon=w.p[at+12],flags=w.u(at+15,2);Dictionary physical=p["physical"];
    Dictionary row=fields(w,at,{{"clip",13,U16},{"stroke",17,F},{"carry",21,U8},{"pack_until",32,F},{"carried_rounds",36,U16},{"event",38,U32}});
    row["mag"]=bool(flags&2);row["ready"]=bool(flags&4);row["locked"]=bool(flags&32);row["grab"]=(flags&8)?"rack":(flags&1024)?"magazine":int64_t(row["carry"])>0?"ammo":"";physical[weapon]=row;
    p["reloading"]=w.s(at+22,1);p["reload_at"]=w.f(at+23);p["cycling"]=w.s(at+27,1);p["cycle_at"]=w.f(at+28);
   }else if(kind==3){
    if(entities.has(key))return {};
    Dictionary row=fields(w,at,{{"owner",8,S64},{"life",16,U32},{"team",20,S8},{"weapon",21,U8},{"position",22,V},{"velocity",34,V},{"remaining",46,F},{"gravity",51,F},{"arm",55,F},{"radius",59,F},{"age",63,F}});
    row["stuck"]=bool(w.p[at+50]&1);row["quake"]=bool(w.p[at+50]&2);entities[key]=row;
   }else if(kind==4){
    Dictionary jet=fields(w,at,{{"mode",12,U8},{"age",13,F},{"cooldown",17,F},{"tap",21,F},{"distance",25,F},{"activation",37,U32}});jet["heading"]=Vector2(w.f(at+29),w.f(at+33));p["jetpack"]=jet;
   }else if(kind==5){
    int flags=w.p[at+15];Dictionary role=fields(w,at,{{"role",12,U8},{"next",13,U8},{"primary_t2",143,U8},{"secondary_t2",144,U8},{"utility_t2",145,U8}});role["equipped_t2"]=w.p[at+14]==2;
    Array xp;for(int j=0;j<4;++j)xp.append(w.s(at+16+j*4,4));role["xp"]=xp;
    const char*timers[]={"box_ready","cloak_until","cloak_ready","drone_ready","strike_ready","turret_ready","blind_until"};for(int j=0;j<7;++j)role[timers[j]]=w.f(at+66+j*4);p["class"]=role;
    Dictionary values=fields(w,at,{{"vehicle_seat",146,S8},{"armor",32,U16},{"armor_tier",34,U8},{"grenades",35,U8},{"vehicle",36,S16},{"kills",38,S32},{"deaths",42,S32},{"bleed_remaining",46,F},{"inject_progress",50,F},{"injector",54,S64},{"injector_life",62,U32}});p.merge(values,true);
    p["weapon_held"]=!(flags&16);p["staging"]=bool(flags&8);p["incapacitated"]=bool(flags&1);p["nvg"]=bool(flags&2);p["gibbed"]=bool(flags&4);
    Array spotted;spotted.append(w.f(at+94));spotted.append(w.f(at+98));p["spotted"]=spotted;p["designation"]=fields(w,at,{{"active",102,B},{"start",103,V},{"position",115,V},{"direction",127,V},{"until",139,F}});
   }else if(kind==14){
    Dictionary values=fields(w,at,{{"cooldown",14,F},{"invulnerable",18,F},{"respawn_at",22,F},{"stamina",26,F},{"lock_vehicle",30,U64},{"lock_elapsed",38,F},{"melee_ready",42,F},{"grenade_ready",47,F},{"grenade_until",51,F},{"reloading",55,S8},{"reload_at",56,F},{"cycling",60,S8},{"cycle_at",61,F},{"charge_at",65,F},{"salvo_left",69,U8},{"burst_left",70,U8},{"jump_ack",71,U32},{"jetpack_ack",75,U32},{"fire_ack",79,U32}});p.merge(values,true);
    int flags=w.p[at+46];p["grenade_primed"]=bool(flags&1);p["grenade_selected"]=bool(flags&2);p["grenade_offhand"]=bool(flags&4);Array owned;int mask=p.get("tier_mask",int64_t(w.u(at+12,2)));for(int j=0;j<17;++j)if(mask&(1<<j))owned.append(j);p["owned"]=owned;
   }else if(kind==15){p["squad"]=int(w.p[at+12])-1;p["combat_until"]=w.f(at+13);
   }else if(kind==16){p["tier_mask"]=int64_t(w.u(at+12,4));p["primary_t3"]=int(w.p[at+26]);PackedInt32Array clips=p["clips"];for(int j=0;j<5;++j)clips.set(12+j,w.u(at+16+j*2,2));p["clips"]=clips;
   }else{
    if(entities.has(key))return {};Dictionary row;
    if(kind==7)row=fields(w,at,{{"team",20,S8},{"health",21,B},{"position",22,V},{"remaining",34,U16}});
    else if(kind==8)row=fields(w,at,{{"team",20,S8},{"position",21,V},{"health",33,U16},{"energy",35,F},{"until",39,F},{"hit_at",43,F}});
    else if(kind==9){row=fields(w,at,{{"index",8,U8},{"kind",9,U8},{"team",10,S8},{"pilot",12,S64},{"life",20,U32},{"position",24,V},{"velocity",36,V},{"direction",48,V},{"normal",60,V},{"yaw",72,F},{"hp",76,F},{"visual_y",80,F},{"reload_at",84,F},{"next",88,F},{"shot_at",92,F},{"rounds",96,U8},{"remaining",97,U8}});row["grounded"]=bool(w.p[at+11]&1);row["headlights"]=bool(w.p[at+11]&2);}
    else if(kind==10)row=fields(w,at,{{"team",20,S8},{"position",21,V},{"direction",33,V},{"hp",45,F},{"ammo",49,U8},{"shot_at",50,F},{"target_vehicle",54,U64},{"target",62,S64},{"target_life",70,U32}});
    else if(kind==11)row=fields(w,at,{{"strike",8,B},{"team",21,S8},{"start",22,V},{"direction",34,V},{"target",46,V},{"length",58,F},{"at",62,F},{"until",66,F},{"impact_at",70,F},{"step",74,F},{"delivered",78,U8}});
    else if(kind==12)row=fields(w,at,{{"life",20,U32},{"team",24,S8},{"kind",25,U8},{"position",26,V},{"velocity",38,V},{"age",50,F}});
    else if(kind==13)row=fields(w,at,{{"kind",8,U8},{"actor",9,S64},{"life",17,U32},{"entity",21,U64},{"position",29,V},{"direction",41,V},{"at",53,F},{"value",57,F},{"detail",61,S16}});
    if(kind==7||kind==8||kind==10||kind==11||kind==12){row["owner"]=w.s(at+8+(kind==11?1:0),8);row["token"]=int64_t(w.u(at+16+(kind==11?1:0),4));}entities[key]=row;
   }
   at+=size;
  }
 }
 return out;
}
}
