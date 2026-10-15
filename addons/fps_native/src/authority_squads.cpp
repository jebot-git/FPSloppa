#include "authority_core.h"
#include "authority_transport_geometry.h"
namespace cqauthority {
int Core::squad_size(int team,int squad) const {
  int count=0;for(const auto &p:players_)count+=p.active&&p.team==team&&p.squad==squad;return count;
}
bool Core::join_squad(Handle h,int squad) {
  auto *p=resolve(h);
  if(!cq.squads||!p||(!p->staging&&!p->dead))return false;
  if(squad==-1){squad=0;for(int s=1;s<4;++s)if(squad_size(p->team,s)<squad_size(p->team,squad))squad=s;}
  if(squad<0||squad>=4)return false;
  if(p->squad==squad)return true;
  if(squad_size(p->team,squad)>=8)return false;
  p->squad=squad;return true;
}
bool Core::ground_spawn(const Player &p,V anchor,Host &host,V &out) {
  for(int i=0;i<17;++i){
    double angle=(i%8)*.7853981633974483;
    double radius=i==0?0:i<=8?2.2:4.4;
    V at=anchor+V{std::cos(angle)*radius,0,std::sin(angle)*radius};
    auto ground=host.world_trace(at+V{0,1.5,0},at-V{0,5,0},p.handle);
    if(ground.blocked){if(ground.normal.y<.6)continue;at.y=ground.position.y+.04;}
    else at.y=host.ground_height(at.x,at.z)+.04;
    if(std::abs(at.y-anchor.y)>3||std::abs(at.x)>cq.map_limit-2||std::abs(at.z)>cq.map_limit-2||host.water(at)||!host.clear_exit(p.handle,at,0))continue;
    bool occupied=false;for(const auto &other:players_)if(alive(other)&&other.handle!=p.handle&&(other.position-at).length()<.9){occupied=true;break;}
    if(occupied)continue;
    out=at;return true;
  }
  return false;
}
bool Core::squad_deploy(Player &p,int kind,int target,int life,Host &host) {
  if(!cq.squads||points.winner!=-2||p.squad<0||(!p.staging&&!p.dead)||(p.dead&&time_<p.respawn_at))return false;
  V at;int vehicle=-1,seat=-1;
  if(kind==0){at=spawn_site(p,host);if(!at.finite())return false;}
  else if(kind==1){
    if(target<0||size_t(target)>=points.count)return false;
    const auto &zone=points.zones[size_t(target)];
    if(zone.owner!=p.team||zone.contested||!ground_spawn(p,zone.position,host,at))return false;
  }else if(kind==2){
    auto *buddy=resolve({target,uint32_t(life)});
    if(!buddy||buddy==&p||!alive(*buddy)||buddy->team!=p.team||buddy->squad!=p.squad||buddy->combat_until>time_)return false;
    if(buddy->vehicle>=0){
      auto &v=vehicles_[size_t(buddy->vehicle)];
      if(!v.active||v.hp<=0||v.team!=p.team||v.kind!=VehicleKind::TRANSPORT)return false;
      for(size_t i=0;i<v.seats.size();++i)if(i!=6 && !v.seats[i].id){seat=int(i);break;}
      if(seat<0)return false;
      vehicle=buddy->vehicle;at=transport_seat(v,seat);
    }else if(!ground_spawn(p,buddy->position,host,at))return false;
  }else return false;
  Player *fresh=&p;
  if(p.dead){auto next=respawn(p.handle,at);fresh=resolve(next);if(!fresh)return false;}
  else spawn_class(p);
  fresh->staging=false;fresh->hp=100;fresh->position=at;fresh->velocity={};fresh->combat_until=0;
  if(vehicle>=0){
    auto &v=vehicles_[size_t(vehicle)];v.seats[size_t(seat)]=fresh->handle;
    fresh->vehicle=vehicle;fresh->vehicle_seat=seat;fresh->use_ready=time_+.5;
  }
  host.seat(fresh->handle,at,vehicle>=0);return true;
}
} // namespace cqauthority
