#include "navigation.h"
#include <queue>
#include <unordered_set>
namespace cqserver {
namespace {
uint64_t key(int x,int z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
struct Quant {int32_t x,y,z;bool operator==(const Quant&b)const{return x==b.x&&y==b.y&&z==b.z;}};
struct Hash {size_t operator()(const Quant&p)const{return size_t(uint32_t(p.x))*73856093U^size_t(uint32_t(p.y))*19349663U^size_t(uint32_t(p.z))*83492791U;}};
V closest_triangle(V p,V a,V b,V c){
 V ab=b-a,ac=c-a,ap=p-a;double d1=ab.dot(ap),d2=ac.dot(ap);if(d1<=0&&d2<=0)return a;
 V bp=p-b;double d3=ab.dot(bp),d4=ac.dot(bp);if(d3>=0&&d4<=d3)return b;
 double vc=d1*d4-d3*d2;if(vc<=0&&d1>=0&&d3<=0)return a+ab*(d1/(d1-d3));
 V cp=p-c;double d5=ab.dot(cp),d6=ac.dot(cp);if(d6>=0&&d5<=d6)return c;
 double vb=d5*d2-d1*d6;if(vb<=0&&d2>=0&&d6<=0)return a+ac*(d2/(d2-d6));
 double va=d3*d6-d5*d4;if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0)return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)));
 double total=va+vb+vc;if(std::abs(total)<1e-18)return a;return a+ab*(vb/total)+ac*(vc/total);
}
}
Navigation::Navigation(const std::filesystem::path&file,const Json&links,const Json&roads_data){
 auto bytes=read_file(file,256*1024*1024);size_t offset=0;
 auto next=[&](){if(offset+4>bytes.size())throw std::runtime_error("Truncated navigation");uint32_t n=u32(bytes.data()+offset);offset+=4;return n;};
 if(next()!=0x314e5143)throw std::runtime_error("Invalid navigation header");uint32_t regions=next();if(regions>4096)throw std::runtime_error("Navigation region limit");
 std::unordered_map<Quant,uint32_t,Hash>unique;unique.reserve(1000000);
 for(uint32_t region=0;region<regions;++region){uint32_t count=next();if(count>4000000||offset+uint64_t(count)*12>bytes.size())throw std::runtime_error("Navigation vertex limit");std::vector<uint32_t>remap;remap.reserve(count);
  for(uint32_t i=0;i<count;++i){Point p{f32(bytes.data()+offset),f32(bytes.data()+offset+4),f32(bytes.data()+offset+8)};offset+=12;if(!V(p).finite())throw std::runtime_error("Non-finite navigation vertex");Quant q{int32_t(std::llround(p.x/.0003)),int32_t(std::llround(p.y/.0003)),int32_t(std::llround(p.z/.0003))};auto it=unique.find(q);if(it==unique.end()){uint32_t id=uint32_t(vertices_.size());unique[q]=id;vertices_.push_back(p);remap.push_back(id);}else remap.push_back(it->second);}
  uint32_t polygons=next();if(polygons>4000000||polygons_.size()+polygons>4000000)throw std::runtime_error("Navigation polygon limit");
  for(uint32_t i=0;i<polygons;++i){uint32_t n=next();if(n<3||n>32)throw std::runtime_error("Invalid navigation polygon");Poly p;p.first=uint32_t(indices_.size());p.count=uint16_t(n);for(uint32_t j=0;j<n;++j){uint32_t local=next();if(local>=remap.size())throw std::runtime_error("Navigation index overflow");uint32_t index=remap[local];indices_.push_back(index);p.center=p.center+V(vertices_[index]);}p.center=p.center/double(n);polygons_.push_back(p);}
 }
 if(offset!=bytes.size())throw std::runtime_error("Unexpected navigation payload");unique.clear();unique.rehash(0);
 struct Edge{uint64_t vertices;uint32_t polygon;};std::vector<Edge>edges;edges.reserve(indices_.size());adjacency_.resize(polygons_.size());
 for(uint32_t i=0;i<polygons_.size();++i){auto&p=polygons_[i];double lx=1e30,hx=-1e30,lz=1e30,hz=-1e30;
  for(uint32_t j=0;j<p.count;++j){uint32_t a=indices_[p.first+j],b=indices_[p.first+(j+1)%p.count];if(a!=b)edges.push_back({(uint64_t(std::min(a,b))<<32)|std::max(a,b),i});auto v=vertices_[a];lx=std::min(lx,double(v.x));hx=std::max(hx,double(v.x));lz=std::min(lz,double(v.z));hz=std::max(hz,double(v.z));}
  for(int z=int(std::floor(lz/16));z<=int(std::floor(hz/16));++z)for(int x=int(std::floor(lx/16));x<=int(std::floor(hx/16));++x)bins_[key(x,z)].push_back(i);
 }
 std::sort(edges.begin(),edges.end(),[](auto&a,auto&b){return a.vertices<b.vertices||(a.vertices==b.vertices&&a.polygon<b.polygon);});
 for(size_t i=0;i<edges.size();){size_t end=i+1;while(end<edges.size()&&edges[end].vertices==edges[i].vertices)++end;if(end-i==2&&edges[i].polygon!=edges[i+1].polygon){auto a=edges[i].polygon,b=edges[i+1].polygon;adjacency_[a].push_back(b);adjacency_[b].push_back(a);}else if(end-i>2)++ambiguous_edges;i=end;}
 edges.clear();edges.shrink_to_fit();
 for(auto&link:links){V a=vec(link.at(0)),b=vec(link.at(1));auto ia=nearest(a,4,nullptr),ib=nearest(b,4,nullptr);if(ia!=UINT32_MAX&&ib!=UINT32_MAX&&ia!=ib){adjacency_[ia].push_back(ib);adjacency_[ib].push_back(ia);}}
 roads(roads_data);
}
uint32_t Navigation::nearest(V at,double limit,V*point)const{
 double best=limit*limit;uint32_t id=UINT32_MAX;V closest_point;int cx=int(std::floor(at.x/16)),cz=int(std::floor(at.z/16));
 std::unordered_set<uint32_t>visited;
 for(int z=cz-1;z<=cz+1;++z)for(int x=cx-1;x<=cx+1;++x){auto found=bins_.find(key(x,z));if(found==bins_.end())continue;for(auto index:found->second){if(!visited.insert(index).second)continue;const auto&p=polygons_[index];V a=vertices_[indices_[p.first]];for(uint32_t j=1;j+1<p.count;++j){V v=closest_triangle(at,a,vertices_[indices_[p.first+j]],vertices_[indices_[p.first+j+1]]);double distance=(v-at).length2();if(distance<best){best=distance;id=index;closest_point=v;}}}}
 if(id!=UINT32_MAX&&point)*point=closest_point;return id;
}
std::vector<V> Navigation::local(V from,V to){
 V begin,end;uint32_t start=nearest(from,3,&begin),goal=nearest(to,3,&end);if(start==UINT32_MAX||goal==UINT32_MAX)return {};
 struct Cost{double score;uint32_t id;bool operator<(const Cost&b)const{return score>b.score;}};
 std::priority_queue<Cost>queue;std::unordered_map<uint32_t,double>cost;std::unordered_map<uint32_t,uint32_t>previous;std::unordered_set<uint32_t>closed;
 cost[start]=0;queue.push({(polygons_[start].center-end).length(),start});uint32_t iterations=0;
 while(!queue.empty()&&iterations<4096){uint32_t current=queue.top().id;queue.pop();if(!closed.insert(current).second)continue;++iterations;if(current==goal)break;
  for(uint32_t next:adjacency_[current]){if(closed.count(next)||(polygons_[next].center-from).length()>180)continue;double value=cost[current]+(polygons_[next].center-polygons_[current].center).length();auto old=cost.find(next);if(old==cost.end()||value<old->second){cost[next]=value;previous[next]=current;queue.push({value+(polygons_[next].center-end).length(),next});}}
 }
 expanded+=iterations;if(!closed.count(goal))return {};std::vector<uint32_t>polys;for(uint32_t i=goal;i!=start;i=previous.at(i)){polys.push_back(i);if(polys.size()>4096)return {};}
 std::reverse(polys.begin(),polys.end());std::vector<V>path;path.push_back(begin);size_t consumed=0;for(auto i:polys){++consumed;V p=polygons_[i].center;if((p-path.back()).length()>.45)path.push_back(p);if(path.size()>=63)break;}if(consumed==polys.size()&&path.size()<64)path.push_back(end);return path;
}
void Navigation::roads(const Json&data){
 struct Road{V a,b;std::vector<std::pair<double,uint32_t>>cuts;};std::vector<Road>roads;
 std::unordered_map<uint64_t,uint32_t>ids;
 auto point=[&](V p){auto k=key(int(std::llround(p.x*100)),int(std::llround(p.z*100)));auto found=ids.find(k);if(found!=ids.end())return found->second;uint32_t id=uint32_t(road_points_.size());ids[k]=id;road_points_.push_back(p);road_edges_.emplace_back();return id;};
 for(const auto&r:data){V a=vec(r.at("a")),b=vec(r.at("b"));roads.push_back({a,b,{{0,point(a)},{1,point(b)}}});}
 auto cross=[](V a,V b){return a.x*b.z-a.z*b.x;};
 for(size_t i=0;i<roads.size();++i)for(size_t j=i+1;j<roads.size();++j){auto&a=roads[i];auto&b=roads[j];V d=a.b-a.a,e=b.b-b.a;double denominator=cross(d,e);if(std::abs(denominator)<1e-8)continue;double t=cross(b.a-a.a,e)/denominator,u=cross(b.a-a.a,d)/denominator;if(t<0||t>1||u<0||u>1)continue;uint32_t id=point(a.a+d*t);a.cuts.push_back({t,id});b.cuts.push_back({u,id});}
 for(auto&r:roads){std::sort(r.cuts.begin(),r.cuts.end());for(size_t i=1;i<r.cuts.size();++i){auto a=r.cuts[i-1].second,b=r.cuts[i].second;if(a!=b){road_edges_[a].push_back(b);road_edges_[b].push_back(a);}}}
}
std::vector<V> Navigation::path(V from,V to){
 ++queries;V goal=to;
 if((to-from).length()>120&&!road_points_.empty()){
  auto closest=[&](V p){uint32_t id=0;double best=1e30;for(uint32_t i=0;i<road_points_.size();++i){double d=(road_points_[i]-p).length2();if(d<best){best=d;id=i;}}return id;};uint32_t start=closest(from),end=closest(to);
  std::vector<double>distance(road_points_.size(),cqauthority::infinity);std::vector<uint32_t>prev(road_points_.size(),UINT32_MAX);using Entry=std::pair<double,uint32_t>;std::priority_queue<Entry,std::vector<Entry>,std::greater<Entry>>queue;distance[start]=0;queue.push({0,start});
  while(!queue.empty()){auto [score,id]=queue.top();queue.pop();if(score!=distance[id])continue;if(id==end)break;for(auto next:road_edges_[id]){double cost=score+(road_points_[next]-road_points_[id]).length();if(cost<distance[next]){distance[next]=cost;prev[next]=id;queue.push({cost,next});}}}
  if(!std::isfinite(distance[end])){++failed;return {};}
  std::vector<uint32_t>ids;for(uint32_t at=end;at!=UINT32_MAX;at=prev[at]){ids.push_back(at);if(at==start)break;}std::reverse(ids.begin(),ids.end());goal=road_points_[ids.front()];for(auto id:ids){if((road_points_[id]-from).length()>120)break;goal=road_points_[id];}if((goal-from).length()<2&&ids.size()>1)goal=road_points_[ids[1]];
 }
 auto out=local(from,goal);if(out.empty())++failed;return out;
}
}
