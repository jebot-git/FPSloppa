#include "client_session.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <algorithm>
#include <cmath>
#include <vector>
using namespace godot;
namespace {
Dictionary error(const String &message) { Dictionary d; d["ok"]=false; d["error"]=message; return d; }
bool number(const Variant &v) { return (v.get_type()==Variant::INT||v.get_type()==Variant::FLOAT)&&std::isfinite(double(v)); }
bool integer(const Variant &v) { return v.get_type()==Variant::INT || (v.get_type()==Variant::FLOAT && std::isfinite(double(v)) && std::trunc(double(v))==double(v) && std::abs(double(v))<=2147483647.); }
bool hash_valid(const String &s) { if(s.length()!=64)return false; for(int i=0;i<64;++i)if(!((s[i]>='0'&&s[i]<='9')||(s[i]>='a'&&s[i]<='f')))return false; return true; }
bool legacy_valid(const Array &rows,const Array &teams,const Array &palette) {
 if(rows.size()>4096)return false; std::set<int64_t> seen;
 for(int i=0;i<rows.size();++i) {
  if(rows[i].get_type()!=Variant::ARRAY)return false; Array r=rows[i];
  if(r.size()<7||!integer(r[0])||int64_t(r[0])==0||!seen.insert(r[0]).second||r[1].get_type()!=Variant::STRING||!integer(r[2])||r[3].get_type()!=Variant::VECTOR3||!Vector3(r[3]).is_finite()||!number(r[4])||r[5].get_type()!=Variant::BOOL||!integer(r[6]))return false;
  int64_t color=r[2],team=r[6];if(color<0||color>=palette.size()||team < -1||team>=teams.size())return false;
 }
 return true;
}
}
void FPSClientSession::_bind_methods() {
 ClassDB::bind_method(D_METHOD("reset"),&FPSClientSession::reset);
 ClassDB::bind_method(D_METHOD("welcome","data","map_hash"),&FPSClientSession::welcome);
 ClassDB::bind_method(D_METHOD("catalog_update","rows"),&FPSClientSession::catalog_update);
 ClassDB::bind_method(D_METHOD("roster_plan","rows","entries","queued","requested","downloading","players"),&FPSClientSession::roster_plan);
 ClassDB::bind_method(D_METHOD("apply_roster","arena","rows","team_colors","palette","mine"),&FPSClientSession::apply_roster);
 ClassDB::bind_method(D_METHOD("accept_frame","frame","origin","epoch"),&FPSClientSession::accept_frame);
 ClassDB::bind_method(D_METHOD("actions","kind","life","a","b","c"),&FPSClientSession::actions);
 ClassDB::bind_method(D_METHOD("stats"),&FPSClientSession::stats);
}
void FPSClientSession::reset() { ++generation_; members_.clear();catalog_.clear();epoch_=-1;mine_=0;tick_=-1;event_=0;round_=-1;sequence_=0;admitted_=deployment_=staging_=false; }
Dictionary FPSClientSession::welcome(const Dictionary &d,const String &map_hash) {
 if(admitted_)return error("Duplicate standalone admission.");
 if(String(d.get("protocol",String()))!="fpsloppa-cq-native-1"||String(d.get("map_sha256",String()))!=map_hash)return error("Standalone server map/protocol mismatch.");
 for(auto k:{"id","epoch","capacity"})if(!d.has(k)||!integer(d[k]))return error("Invalid standalone admission.");
 int64_t id=d["id"],epoch=d["epoch"],capacity=d["capacity"];
 if(id<=0||id>2147483647||epoch<0||capacity<1||capacity>4096||!d.has("time")||!number(d["time"]))return error("Invalid standalone admission.");
 mine_=id;epoch_=epoch;admitted_=true;Dictionary out;out["ok"]=true;return out;
}
Dictionary FPSClientSession::catalog_update(const Array &rows) {
 // Retain only bounded validated entries; invalid catalog rows never become transfers.
 for(int i=0;i<std::min<int64_t>(rows.size(),4096);++i) {
  if(rows[i].get_type()!=Variant::DICTIONARY)continue;Dictionary r=rows[i];String hash=r.get("hash",String());Variant size=r.get("size",0);
  if(!hash_valid(hash)||!integer(size)||int64_t(size)<16||int64_t(size)>25000000||(!catalog_.has(hash)&&catalog_.size()>=4096))continue;
  catalog_[hash]=r.duplicate(true);
 }
 return catalog_.duplicate(true);
}
Dictionary FPSClientSession::roster_plan(const Array &rows,const Dictionary &entries,const Array &queued,const String &requested,const String &downloading,const Dictionary &players) {
 if(!admitted_||rows.size()>4096)return error("Invalid standalone roster.");
 std::set<int64_t> ids;Array legacy,pinned,removed,downloads;Dictionary choices;std::set<String> waiting;
 for(int i=0;i<queued.size();++i)waiting.insert(queued[i]);waiting.insert(requested);waiting.insert(downloading);
 for(int i=0;i<rows.size();++i) {
  if(rows[i].get_type()!=Variant::DICTIONARY)return error("Invalid standalone roster.");Dictionary r=rows[i];
  if(!r.has("id")||!integer(r["id"])||int64_t(r["id"])==0||(int64_t(r["id"]) < -2147483647 || int64_t(r["id"])>2147483647)||!ids.insert(r["id"]).second||r.get("name",Variant()).get_type()!=Variant::STRING||r.get("avatar",Variant()).get_type()!=Variant::STRING||r.get("spectator",Variant()).get_type()!=Variant::BOOL||!integer(r.get("team",Variant())))return error("Invalid standalone roster.");
  int64_t id=r["id"];int64_t team=r["team"];String hash=r["avatar"];if(team < -1||team>3)return error("Invalid standalone roster team.");
  legacy.push_back(Array::make(id,r["name"],((id%8)+8)%8,Vector3(),0.,r["spectator"],team));
  if(catalog_.has(hash)) {
   Dictionary asset=catalog_[hash],choice;choice["hash"]=hash;choice["size"]=asset["size"];choices[id]=choice;pinned.push_back(hash);
   if(!entries.has(hash)&&waiting.insert(hash).second)downloads.push_back(hash);
  }
 }
 Array previous=players.keys();for(int i=0;i<previous.size();++i)if(!ids.count(previous[i]))removed.push_back(previous[i]);
 // Commit membership only after validating the complete roster.
 for(auto it=members_.begin();it!=members_.end();)if(!ids.count(it->first))it=members_.erase(it);else ++it;
 for(auto id:ids)members_.try_emplace(id);
 Dictionary out;out["ok"]=true;out["rows"]=legacy;out["choices"]=choices;out["pinned"]=pinned;out["removed"]=removed;out["downloads"]=downloads;return out;
}
bool FPSClientSession::apply_roster(Node *arena,const Array &rows,const Array &team_colors,const Array &palette,int64_t mine) {
 if(!arena||!legacy_valid(rows,team_colors,palette))return false;
 Dictionary players=arena->get("players"),fighters=arena->get("fighters");std::set<int64_t> keep;
 for(int i=0;i<rows.size();++i) {
  Array r=rows[i];int64_t id=r[0];keep.insert(id);Dictionary state;
  if(!players.has(id)) {
   // Existing scene factories supply resource/signal wiring once per admission.
   Variant created=arena->call("_new_state",r[1],id);if(created.get_type()!=Variant::DICTIONARY)return false;state=created;
   state["color"]=r[2];state["spectator"]=r[5];state["dead"]=r[5];state["team"]=r[6];players[id]=state;
   arena->call("_create_fighter",id);
   Object *object=fighters.get(id,Variant());auto *actor=Object::cast_to<CharacterBody3D>(object);if(!actor)return false;
   actor->set_position(r[3]);state["yaw"]=r[4];if(id==mine)arena->set("local_yaw",r[4]);
  } else state=players[id];
  state["team"]=r[6];Object *object=fighters.get(id,Variant());auto *actor=Object::cast_to<CharacterBody3D>(object);if(!actor)return false;
  auto &member=members_[id];int team=r[6],color=state["color"];String name=state["name"];
  if(member.binding!=actor->get_instance_id()||member.team!=team||member.color!=color||member.name!=name) {
   Variant label=actor->get("label");
   if(label.get_type()==Variant::OBJECT&&static_cast<Object*>(label))actor->call("set_nametag",name,team,team>=0?team_colors[team]:palette[color]);
   member.binding=actor->get_instance_id();member.team=team;member.color=color;member.name=name;
  }
 }
 Array keys=players.keys();Object *interpolation=arena->get("remote_interpolation");
 for(int i=0;i<keys.size();++i) {
  int64_t id=keys[i];if(keep.count(id))continue;
  Object *object=fighters.get(id,Variant());if(auto *node=Object::cast_to<Node>(object))node->queue_free();
  fighters.erase(id);players.erase(id);members_.erase(id);if(interpolation)interpolation->call("erase",id);
 }
 return true;
}
Dictionary FPSClientSession::accept_frame(const Dictionary &frame,double origin,int64_t epoch) {
 Dictionary out;out["accepted"]=false;
 if(!admitted_||epoch!=epoch_||!std::isfinite(origin)||!integer(frame.get("tick",Variant()))||int64_t(frame["tick"])<=tick_||frame.get("players",Variant()).get_type()!=Variant::DICTIONARY||frame.get("mode",Variant()).get_type()!=Variant::DICTIONARY)return out;
 if(frame.has("events")&&frame["events"].get_type()!=Variant::DICTIONARY)return out;
 Dictionary players=frame["players"],mode=frame["mode"],events=frame.get("events",Dictionary());if(players.size()>4096||events.size()>4096)return out;
 // Preflight before advancing watermarks or life state.
 Array ids=players.keys();for(int i=0;i<ids.size();++i) {if(!integer(ids[i])||players[ids[i]].get_type()!=Variant::DICTIONARY)return out;Dictionary p=players[ids[i]];if(!integer(p.get("life",Variant())))return out;}
 std::vector<int64_t> order;Array event_ids=events.keys();for(int i=0;i<event_ids.size();++i){if(!integer(event_ids[i])||events[event_ids[i]].get_type()!=Variant::DICTIONARY)return out;order.push_back(event_ids[i]);}std::sort(order.begin(),order.end());
 Dictionary selected;for(auto seq:order)if(seq>event_) {selected[seq]=events[seq];event_=seq;}
 Array deaths,life_changes;
 for(int i=0;i<ids.size();++i) {
  int64_t id=ids[i];auto member=members_.find(id);if(member==members_.end())continue;Dictionary p=players[id];int64_t life=p["life"];bool dead=p.get("dead",false);
  if(member->second.life!=life)life_changes.push_back(id);
  if(dead&&(member->second.life!=life||!member->second.dead)){Dictionary death;death["id"]=id;death["player"]=p.duplicate();deaths.push_back(death);}
  member->second.life=life;member->second.dead=dead;
 }
 bool was_staging=staging_;Dictionary local=players.get(mine_,Dictionary());staging_=local.get("staging",false);
 bool deploy=!deployment_;deployment_=true;bool round_end=double(mode.get("intermission",0.))>0&&int64_t(mode.get("epoch",-1))!=round_;if(round_end)round_=mode.get("epoch",-1);
 tick_=frame["tick"];out["accepted"]=true;out["was_staging"]=was_staging;out["deployment_offer"]=deploy;out["round_end"]=round_end;out["events"]=selected;out["deaths"]=deaths;out["life_changes"]=life_changes;return out;
}
Array FPSClientSession::actions(int kind,int64_t life,int a,int b,int c) {
 Array result;if(!admitted_||kind<0||kind>32||life<0||sequence_>=2147483645)return result;
 auto append=[&](int k,int x,int y,int z){Dictionary d;d["life"]=life;d["seq"]=++sequence_;d["kind"]=k;d["a"]=x;d["b"]=y;d["c"]=z;result.push_back(d);};
 if(kind==10){append(11,-1,0,0);append(12,0,0,0);}else append(kind,a,b,c);return result;
}
Dictionary FPSClientSession::stats() const {
 Dictionary d;d["generation"]=generation_;d["admitted"]=admitted_;d["epoch"]=epoch_;d["mine"]=mine_;d["tick"]=tick_;d["event"]=event_;d["members"]=int64_t(members_.size());d["catalog"]=catalog_.size();d["sequence"]=sequence_;int64_t bound=0;
 for(const auto &pair:members_)if(pair.second.binding&&ObjectDB::get_instance(pair.second.binding))++bound;d["bound"]=bound;return d;
}
