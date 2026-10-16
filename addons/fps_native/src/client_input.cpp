#include <godot_cpp/variant/variant.hpp>
#include "codec.h"
#include <godot_cpp/variant/transform3d.hpp>
#include <cstring>
#include <cmath>
using namespace godot;
PackedByteArray FPSCodec::encode_authority_input(const Dictionary&c)const{
 const char*required[]={"life","seq","move","yaw","pitch","weapon","fire","jump","reload","slow","crouch","prone","blocked"};
 for(auto key:required)if(!c.has(key))return {};
 if(Variant(c["move"]).get_type()!=Variant::VECTOR2)return {};
 Dictionary pose=c.get("xr",Dictionary());bool tracked=!pose.is_empty(),offhand=tracked&&pose.has("offhand_weapon");
 bool redundant=c.has("jump_event")||c.has("jetpack_event")||c.has("fire_event");
 bool vr=c.get("vr_device",tracked),rewind=c.has("view_time"),swimming=c.has("swim");
 auto flag=[&](const char*key){return bool(c.get(key,false));};
 bool extended=flag("offhand_fire")||flag("reload_trigger")||flag("reload_grip")||c.has("weapon_held")||vr||tracked||flag("jetpack")||rewind||flag("cq_drag")||flag("melee")||flag("respawn")||redundant||swimming;
 int tail=tracked?(offhand?288:240):48;
 PackedByteArray bytes;bytes.resize((tracked?tail:extended?48:30)+(rewind?4:0)+(redundant?18:0)+(swimming?12:0));
 auto*p=bytes.ptrw();std::memset(p,0,bytes.size());std::memcpy(p,swimming?"CQI3":extended?"CQI2":"CQI1",4);
 auto put=[&](int at,uint64_t v,int n){for(int i=0;i<n;++i)p[at+i]=uint8_t(v>>(i*8));};
 bool valid=true;auto f=[&](int at,double v){if(!std::isfinite(v)){valid=false;return;}float x=float(v);if(!std::isfinite(x)){valid=false;return;}uint32_t bits;std::memcpy(&bits,&x,4);put(at,bits,4);};
 auto v=[&](int at,Vector3 x){f(at,x.x);f(at+4,x.y);f(at+8,x.z);};
 put(4,int64_t(c["life"]),4);put(8,int64_t(c["seq"]),4);Vector2 move=c["move"];f(12,move.x);f(16,move.y);f(20,c["yaw"]);f(24,c["pitch"]);p[28]=int64_t(c["weapon"]);
 p[29]=flag("fire")|(flag("jump")<<1)|(flag("reload")<<2)|(flag("slow")<<3)|(flag("crouch")<<4)|(flag("prone")<<5)|(flag("blocked")<<6);
 if(extended){
  int flags=int(vr)|(int(tracked)<<1)|(int(offhand)<<2)|(int(bool(pose.get("left_handed",false)))<<3)|(int(pose.has("height"))<<4)|(int(flag("reload_grip"))<<5)|(int(flag("jetpack"))<<6)|(int(flag("offhand_fire"))<<7)|(int(rewind)<<8)|(int(flag("cq_drag"))<<9)|(int(flag("melee"))<<10)|(int(flag("respawn"))<<11)|(int(redundant)<<12)|(int(c.has("weapon_held"))<<13)|(int(c.has("weapon_held")&&bool(c.get("weapon_held",true)))<<14)|(int(flag("reload_trigger"))<<15);
  put(30,flags,2);v(32,c.get("room",Vector3()));f(44,pose.get("height",1.65));
  if(tracked){const char*keys[]={"head","left","right","weapon","offhand_weapon"};for(int i=0;i<(offhand?5:4);++i){if(!pose.has(keys[i])||Variant(pose[keys[i]]).get_type()!=Variant::TRANSFORM3D)return {};Transform3D t=pose[keys[i]];int at=48+i*48;for(int j=0;j<3;++j)v(at+j*12,t.basis.get_column(j));v(at+36,t.origin);}}
 }
 if(rewind){f(tail,c["view_time"]);tail+=4;}
 if(redundant){put(tail,int64_t(c.get("jump_event",0)),4);put(tail+4,int64_t(c.get("jump_seq",-1)),4);put(tail+8,int64_t(c.get("jetpack_event",0)),4);Variant edge=c.get("fire_event",Array());if(edge.get_type()==Variant::ARRAY){Array a=edge;if(a.size()==3){put(tail+12,int64_t(a[0]),4);p[tail+16]=int64_t(a[1]);p[tail+17]=int64_t(a[2]);}}}
 if(swimming)v(bytes.size()-12,c["swim"]);
 return valid?bytes:PackedByteArray();
}
