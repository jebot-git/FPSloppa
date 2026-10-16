#include "terrain.h"
namespace cqserver {
namespace {
double mix(double a,double b,double t){return a+(b-a)*t;}
double smooth(double a,double b,double x){double t=std::clamp((x-a)/(b-a),0.,1.);return t*t*(3-2*t);}
uint64_t key(int x,int z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
struct Pcg {
 uint64_t state=0,inc=(1442695040888963407ULL<<1)|1;
 uint32_t next(){uint64_t old=state;state=old*6364136223846793005ULL+inc;uint32_t x=uint32_t(((old>>18)^old)>>27),r=uint32_t(old>>59);return (x>>r)|(x<<((-r)&31));}
 explicit Pcg(uint64_t seed){next();state+=seed;next();}
 float number(){uint32_t exponent=next();if(!exponent)return 0;return std::ldexp(float(next()|0x80000001U),-32-__builtin_clz(exponent));}
};
}
Surface::Surface(const Json&d){
 extent=d.at("extent");tile_side=d.at("tile");
 auto load=[&](const char*k,Bins&out){for(const auto&b:d.at(k)){int x=b.at("cell").at(0),z=b.at("cell").at(1);for(const auto&r:b.at("rows"))out[key(x,z)].push_back({vec(r.at("a")),vec(r.at("b")),r.at("width"),r.value("depth",r.value("earthwork",0.))});}};
 load("roads",roads_);load("earthworks",earthworks_);load("rivers",rivers_);
 for(size_t i=0;i<d.at("centers").size();++i){V p=vec(d.at("centers")[i]);pads_.push_back({p.x,p.y,p.z,d.at("radii")[i]});}
 for(const auto&r:d.at("rocks"))rocks_.push_back(r.get<std::array<double,4>>());for(const auto&r:d.at("cover"))cover_.push_back(r.get<std::array<double,4>>());
}
uint64_t Surface::bin(double x,double z)const{return key(int(std::floor((x+extent*.5)/tile_side)),int(std::floor((z+extent*.5)/tile_side)));}
double Surface::rock(double x,double z)const{double out=0;for(auto r:rocks_)out=std::max(out,1-smooth(.35,1,std::hypot(x-r[0],z-r[1])/r[2]));return out;}
double Surface::natural(double x,double z)const{
 double h=85+std::sin(x*.0032)*std::cos(z*.003)*32+std::sin(x*.011+z*.008)*8;
 constexpr double peaks[][4]={{-300,-1130,380,310},{1030,-1040,350,390},{1110,120,290,205},{-1150,100,300,145},{160,530,310,85}};
 for(auto&p:peaks){double d=std::hypot(x-p[0],z-p[1])/p[2];h+=p[3]*std::exp(-d*d*2.3);}
 double canyon=(1-smooth(28,125,std::abs(x-(-470+std::sin(z*.003)*95))))*(1-smooth(650,1050,std::abs(z)));
 h=mix(h,22+std::sin(z*.009)*5,canyon);
 double second=(1-smooth(22,105,std::abs(z-(-800+std::sin(x*.003)*70))))*smooth(50,260,x)*(1-smooth(850,1250,x));h=mix(h,46+std::sin(x*.006)*7,second);
 for(auto r:rocks_){double d=std::hypot(x-r[0],z-r[1])/r[2];h+=r[3]*(1-smooth(.2,1,d))*(.82+.18*std::sin(x*.09+z*.07));}
 for(auto c:cover_){double d=std::hypot(x-c[0],z-c[1]);if(d<c[2])h+=c[3]*(1-smooth(0,c[2],d));}return h;
}
V Surface::water(double x,double z)const{
 V result;auto found=rivers_.find(key(int(std::floor(x/128)),int(std::floor(z/128))));
 if(found!=rivers_.end())for(auto&r:found->second){V d{r.b.x-r.a.x,0,r.b.z-r.a.z};double t=std::clamp((V{x-r.a.x,0,z-r.a.z}).dot(d)/d.length2(),0.,1.);double mask=1-smooth(r.width,r.width+12,(V{x-r.a.x,0,z-r.a.z}-d*t).length());if(mask>result.x)result={float(mask),float(mix(r.a.y,r.b.y,t)),float(r.earthwork)};}
 for(auto p:pads_)result.x=float(result.x*smooth(p[3]+4,p[3]+16,std::max(std::abs(x-p[0]),std::abs(z-p[2]))));
 if(pads_.size()>2){auto p=pads_[2];double south=z-p[2],d=std::max(0.,south-68),center=p[0]+std::sin(d*.003)*28,width=63+d*.24;double sea=(1-smooth(width,width+11,std::abs(x-center)))*smooth(57,68,south);if(sea>result.x)return {float(sea),0,8};}return result;
}
float Surface::height(double x,double z)const{
 double h=natural(x,z);uint64_t cell=bin(x,z);
 auto project=[&](const Road&r){V d{r.b.x-r.a.x,0,r.b.z-r.a.z};double t=std::clamp(V{x-r.a.x,0,z-r.a.z}.dot(d)/d.length2(),0.,1.);return std::pair<double,double>{t,(V{x-r.a.x,0,z-r.a.z}-d*t).length()};};
 auto foundation=earthworks_.find(cell);double strongest=0,target=h;if(foundation!=earthworks_.end())for(auto&r:foundation->second){auto p=project(r);double influence=1-smooth(r.width+3,r.earthwork,p.second);if(influence>strongest){strongest=influence;target=mix(r.a.y,r.b.y,p.first);}}h=mix(h,target,strongest);
 for(size_t i=5;i<pads_.size();++i){auto p=pads_[i];h=mix(h,p[1],1-smooth(p[3],p[3]+16,std::max(std::abs(x-p[0]),std::abs(z-p[2]))));}
 for(size_t i=0;i<std::min(size_t(5),pads_.size());++i){auto p=pads_[i];h=mix(h,p[1],1-smooth(p[3],p[3]+(i==4?8:28),std::max(std::abs(x-p[0]),std::abs(z-p[2]))));}
 auto found=roads_.find(cell);double nearest=1e30;const Road*road=nullptr;double along=0;if(found!=roads_.end())for(auto&r:found->second){auto p=project(r);if(p.second<nearest){nearest=p.second;road=&r;along=p.first;}}
 if(road)h=mix(h,mix(road->a.y,road->b.y,along),1-smooth(road->width,road->width+5,nearest));
 for(size_t i=5;i<pads_.size();++i){auto p=pads_[i];if(std::max(std::abs(x-p[0]),std::abs(z-p[2]))<=p[3])h=p[1];}
 V w=water(x,z);return float(mix(h,std::min(h,double(float(w.y-w.z))),w.x));
}
bool Surface::planting(double x,double z)const{
 for(size_t i=0;i<pads_.size();++i){auto p=pads_[i];if(std::max(std::abs(x-p[0]),std::abs(z-p[2]))<p[3]+(i<5?16:8))return false;}
 auto found=roads_.find(bin(x,z));double nearest=1e30,width=0;if(found!=roads_.end())for(auto&r:found->second){V d{r.b.x-r.a.x,0,r.b.z-r.a.z};double t=std::clamp(V{x-r.a.x,0,z-r.a.z}.dot(d)/d.length2(),0.,1.);double gap=(V{x-r.a.x,0,z-r.a.z}-d*t).length();if(gap<nearest){nearest=gap;width=r.width;}}
 return !(nearest<width+4)&&water(x,z).x<=.01;
}
Surface::Tile& Surface::tile(int x,int z){
 auto k=key(x,z);auto found=tiles_.find(k);if(found!=tiles_.end()){found->second.use=++use_;return found->second;}
 if(tiles_.size()>=128){auto oldest=std::min_element(tiles_.begin(),tiles_.end(),[](auto&a,auto&b){return a.second.use<b.second.use;});tiles_.erase(oldest);}
 auto&t=tiles_[k];t.use=++use_;t.ox=float(float(x)*float(tile_side)-float(float(extent)*.5f));t.oz=float(float(z)*float(tile_side)-float(float(extent)*.5f));Pcg rng(uint64_t(int64_t(8137)+int64_t(x)*73856093+int64_t(z)*19349663));
 for(int iz=0;iz<32;++iz)for(int ix=0;ix<32;++ix){float fx=float((ix+.25+rng.number()*.5)*2),fz=float((iz+.25+rng.number()*.5)*2);rng.number();float choice=rng.number();int i=iz*32+ix;t.states[i]=choice>.90?3:0;t.px[i]=float(t.ox+float(float(fx*float(tile_side))/64.f));t.pz[i]=float(t.oz+float(float(fz*float(tile_side))/64.f));}return t;
}
V Surface::root(Tile&t,int index){
 if(t.states[index])return t.states[index]==1?t.roots[index]:V{cqauthority::infinity,0,0};
 t.states[index]=2;float x=t.px[index],z=t.pz[index];if(!planting(x,z)||rock(x,z)>.4)return {cqauthority::infinity,0,0};
 float fx=float(float(float(x-t.ox)*64.f)/float(tile_side)),fz=float(float(float(z-t.oz)*64.f)/float(tile_side));int ix=int(std::floor(fx)),iz=int(std::floor(fz));
 auto sample=[&](int sx,int sz){int k=sz*65+sx;auto found=t.heights.find(k);if(found!=t.heights.end())return found->second;float px=float(t.ox+float(float(sx)*float(tile_side)/64.f)),pz=float(t.oz+float(float(sz)*float(tile_side)/64.f));float h=height(px,pz);t.heights[k]=h;return h;};
 double a=sample(ix,iz),b=sample(ix+1,iz),c=sample(ix,iz+1),d=sample(ix+1,iz+1),h=mix(mix(a,b,fx-ix),mix(c,d,fx-ix),fz-iz);
 if(h>=1&&h<=330&&std::hypot(float(b-a),float(c-a))/(tile_side/64.)<=.55){t.states[index]=1;t.roots[index]={x,float(h-.03),z};return t.roots[index];}return {cqauthority::infinity,0,0};
}
bool Surface::grass(V point){
 if(!point.finite()||std::abs(point.x)>extent*.5||std::abs(point.z)>extent*.5)return false;
 const double radius=1.1;int grid=int(std::round(extent/tile_side));
 int lx=int(std::floor((point.x+extent*.5-radius)/tile_side)),hx=int(std::floor((point.x+extent*.5+radius)/tile_side)),lz=int(std::floor((point.z+extent*.5-radius)/tile_side)),hz=int(std::floor((point.z+extent*.5+radius)/tile_side));
 for(int z=std::max(0,lz);z<=std::min(grid-1,hz);++z)for(int x=std::max(0,lx);x<=std::min(grid-1,hx);++x){auto&t=tile(x,z);double fx=(point.x-t.ox)*32/tile_side,fz=(point.z-t.oz)*32/tile_side;int lo_x=std::max(0,int(std::floor(fx-radius*32/tile_side))),hi_x=std::min(31,int(std::floor(fx+radius*32/tile_side))),lo_z=std::max(0,int(std::floor(fz-radius*32/tile_side))),hi_z=std::min(31,int(std::floor(fz+radius*32/tile_side)));
  for(int iz=lo_z;iz<=hi_z;++iz)for(int ix=lo_x;ix<=hi_x;++ix){int i=iz*32+ix;if(t.states[i]==3||std::hypot(point.x-t.px[i],point.z-t.pz[i])>=radius)continue;V at=root(t,i);if(at.finite()&&std::abs(point.y-at.y)<1.5)return true;}
 }return false;
}
}
