#pragma once
// Experimental gameplay collision. No Godot calls, render residency or mutable
// shared query cache. Configure once, then query concurrently with local scratch.
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <limits>
#include <numeric>
#include <thread>
#include <vector>
namespace cqcollision {
constexpr double infinity=std::numeric_limits<double>::infinity();
struct V {
 double x=0,y=0,z=0;
 V operator+(V b)const{return{x+b.x,y+b.y,z+b.z};} V operator-(V b)const{return{x-b.x,y-b.y,z-b.z};}
 V operator-()const{return{-x,-y,-z};} V operator*(double s)const{return{x*s,y*s,z*s};} V operator/(double s)const{return *this*(1/s);}
 double dot(V b)const{return x*b.x+y*b.y+z*b.z;} V cross(V b)const{return{y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x};}
 double length2()const{return dot(*this);} double length()const{return std::sqrt(length2());}
 V unit(V fallback={0,1,0})const{double l=length();return l>1e-12?*this/l:fallback;}
 double at(int i)const{return i==0?x:i==1?y:z;} bool finite()const{return std::isfinite(x)&&std::isfinite(y)&&std::isfinite(z);}
};
struct Basis {V x{1,0,0},y{0,1,0},z{0,0,1};V apply(V v)const{return x*v.x+y*v.y+z*v.z;} V inverse(V v)const{return{x.dot(v),y.dot(v),z.dot(v)};}};
struct Bounds {V lo{infinity,infinity,infinity},hi{-infinity,-infinity,-infinity};
 void add(V p){lo={std::min(lo.x,p.x),std::min(lo.y,p.y),std::min(lo.z,p.z)};hi={std::max(hi.x,p.x),std::max(hi.y,p.y),std::max(hi.z,p.z)};}
 void add(Bounds b){add(b.lo);add(b.hi);} V center()const{return(lo+hi)*.5;} V half()const{return(hi-lo)*.5;}
 bool intersects(Bounds b)const{return lo.x<=b.hi.x&&hi.x>=b.lo.x&&lo.y<=b.hi.y&&hi.y>=b.lo.y&&lo.z<=b.hi.z&&hi.z>=b.lo.z;}
 bool segment(V a,V d,V expand={},double limit=1)const{double near=0,far=limit;for(int i=0;i<3;i++){double p=a.at(i),v=d.at(i),l=lo.at(i)-expand.at(i),h=hi.at(i)+expand.at(i);if(std::abs(v)<1e-14){if(p<l||p>h)return false;}else{double n=(l-p)/v,f=(h-p)/v;if(n>f)std::swap(n,f);near=std::max(near,n);far=std::min(far,f);if(near>far)return false;}}return true;}
};
enum class Kind:uint32_t {box=0,cylinder=1,sphere=2,capsule=3,triangle=4};
struct Shape {Kind kind=Kind::box;int id=0;uint32_t mask=1;V center{},half{.5,.5,.5};Basis basis{};double radius=.3,height=1.65;std::array<V,3> vertices{};V motion{};
 V support(V direction)const{
  if(kind==Kind::triangle){V best=vertices[0];for(int i=1;i<3;i++)if(vertices[i].dot(direction)>best.dot(direction))best=vertices[i];return best;}
  V d=basis.inverse(direction),p{};
  if(kind==Kind::box)p={d.x>=0?half.x:-half.x,d.y>=0?half.y:-half.y,d.z>=0?half.z:-half.z};
  else if(kind==Kind::sphere)p=d.unit()*radius;
  else if(kind==Kind::capsule)p=d.unit()*radius+V{0,d.y>=0?height*.5-radius:radius-height*.5,0};
  else {double h=std::hypot(d.x,d.z);p={h>1e-14?radius*d.x/h:0,d.y>=0?height*.5:-height*.5,h>1e-14?radius*d.z/h:0};}
  return center+basis.apply(p);
 }
 Bounds bounds()const{Bounds b;for(V axis: {V{1,0,0},V{0,1,0},V{0,0,1}}){b.add(support(axis));b.add(support(-axis));}return b;}
};
struct Counters {uint64_t nodes=0,candidates=0,triangles=0,gjk=0,iterations=0,advances=0,recoveries=0,unresolved=0;void add(const Counters &b){nodes+=b.nodes;candidates+=b.candidates;triangles+=b.triangles;gjk+=b.gjk;iterations+=b.iterations;advances+=b.advances;recoveries+=b.recoveries;unresolved+=b.unresolved;}};
struct Hit {bool hit=false,converged=true;double fraction=1,penetration=0;int id=-1;V normal{},point{};};
struct Point {V v,a,b;};
struct Distance {double distance=infinity;V normal{0,1,0},point{};bool converged=false;};
// Closest convex combination on a <=4-point simplex. Exhausting its faces
// avoids fragile hand-coded tetrahedron region branches at thin/coplanar data.
inline V reduce(std::array<Point,4>& simplex,int &size,V &witness){
 double best=infinity;int chosen=0;std::array<double,4> weights{},best_weights{};int n=size;
 for(int bits=1;bits<(1<<n);bits++){
  std::array<int,4> ids{};int k=0;for(int i=0;i<n;i++)if(bits&(1<<i))ids[k++]=i;
  double matrix[5][6]{}; // constrained least squares [G 1; 1 0]
  for(int i=0;i<k;i++){for(int j=0;j<k;j++)matrix[i][j]=simplex[ids[i]].v.dot(simplex[ids[j]].v);matrix[i][k]=1;matrix[k][i]=1;}matrix[k][k+1]=1;
  bool valid=true;for(int col=0;col<=k;col++){int pivot=col;for(int row=col+1;row<=k;row++)if(std::abs(matrix[row][col])>std::abs(matrix[pivot][col]))pivot=row;if(std::abs(matrix[pivot][col])<1e-16){valid=false;break;}for(int j=col;j<=k+1;j++)std::swap(matrix[pivot][j],matrix[col][j]);double scale=matrix[col][col];for(int j=col;j<=k+1;j++)matrix[col][j]/=scale;for(int row=0;row<=k;row++)if(row!=col){double factor=matrix[row][col];for(int j=col;j<=k+1;j++)matrix[row][j]-=factor*matrix[col][j];}}
  if(!valid)continue;
  V p{};weights.fill(0);for(int i=0;i<k;i++){double w=matrix[i][k+1];if(w< -1e-8){valid=false;break;}weights[ids[i]]=std::max(0.,w);p=p+simplex[ids[i]].v*weights[ids[i]];}
  if(valid&&p.length2()<best){best=p.length2();chosen=bits;best_weights=weights;}
 }
 std::array<Point,4> next{};int count=0;V closest{};witness={};for(int i=0;i<n;i++)if((chosen&(1<<i))&&best_weights[i]>1e-10){next[count++]=simplex[i];closest=closest+simplex[i].v*best_weights[i];witness=witness+simplex[i].b*best_weights[i];}simplex=next;size=count;return closest;
}
inline Hit ray_one(const Shape&,V,V);
inline V closest_triangle(V p,V a,V b,V c){
 V ab=b-a,ac=c-a,ap=p-a;double d1=ab.dot(ap),d2=ac.dot(ap);if(d1<=0&&d2<=0)return a;
 V bp=p-b;double d3=ab.dot(bp),d4=ac.dot(bp);if(d3>=0&&d4<=d3)return b;
 double vc=d1*d4-d3*d2;if(vc<=0&&d1>=0&&d3<=0)return a+ab*(d1/(d1-d3));
 V cp=p-c;double d5=ab.dot(cp),d6=ac.dot(cp);if(d6>=0&&d5<=d6)return c;
 double vb=d5*d2-d1*d6;if(vb<=0&&d2>=0&&d6<=0)return a+ac*(d2/(d2-d6));
 double va=d3*d6-d5*d4;if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0)return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)));
 double sum=va+vb+vc;if(std::abs(sum)<1e-20)return a;return a+ab*(vb/sum)+ac*(vc/sum);
}
inline std::pair<V,V> closest_segments(V a,V b,V c,V d){V u=b-a,v=d-c,w=a-c;double uu=u.dot(u),vv=v.dot(v),uv=u.dot(v),uw=u.dot(w),vw=v.dot(w);double s=0,t=0;
 if(uu<1e-20){t=vv>1e-20?std::clamp(vw/vv,0.,1.):0;}else if(vv<1e-20)s=std::clamp(-uw/uu,0.,1.);else{double denom=uu*vv-uv*uv;if(denom>1e-20)s=std::clamp((uv*vw-uw*vv)/denom,0.,1.);t=(uv*s+vw)/vv;if(t<0){t=0;s=std::clamp(-uw/uu,0.,1.);}else if(t>1){t=1;s=std::clamp((uv-uw)/uu,0.,1.);}}return{a+u*s,c+v*t};}
inline bool upright(const Shape&s){return std::abs(s.basis.y.y-1)<1e-8;}
inline bool axis_box(const Shape&s){return(s.basis.x-V{1,0,0}).length2()<1e-14&&(s.basis.y-V{0,1,0}).length2()<1e-14&&(s.basis.z-V{0,0,1}).length2()<1e-14;}
inline bool fast_distance(const Shape&a,const Shape&b,Distance&out){
 auto result=[&](V gap,double radius,V point){double len=gap.length();out={std::max(0.,len-radius),gap.unit(),point,true};return true;};
 bool round=a.kind==Kind::sphere||a.kind==Kind::capsule;
 if(round&&b.kind==Kind::triangle){double half=a.kind==Kind::capsule?std::max(0.,a.height*.5-a.radius):0;V start=a.center-a.basis.y*half,end=a.center+a.basis.y*half;
  Hit crossing=ray_one(b,start,end-start);if(crossing.hit){out={0,(b.vertices[1]-b.vertices[0]).cross(b.vertices[2]-b.vertices[0]).unit(),crossing.point,true};return true;}
  V on=closest_triangle(start,b.vertices[0],b.vertices[1],b.vertices[2]),gap=start-on;
  V p=closest_triangle(end,b.vertices[0],b.vertices[1],b.vertices[2]);if((end-p).length2()<gap.length2()){on=p;gap=end-p;}
  for(int i=0;i<3;i++){auto pair=closest_segments(start,end,b.vertices[i],b.vertices[(i+1)%3]);if((pair.first-pair.second).length2()<gap.length2()){on=pair.second;gap=pair.first-pair.second;}}
  return result(gap,a.radius,on);
 }
 if(b.kind==Kind::box&&(a.kind==Kind::sphere||(round&&upright(a)&&upright(b)))){V p=b.basis.inverse(a.center-b.center);double half=a.kind==Kind::capsule?std::max(0.,a.height*.5-a.radius):0;V line=p;line.y=std::clamp(0.,p.y-half,p.y+half);V on{std::clamp(line.x,-b.half.x,b.half.x),std::clamp(line.y,-b.half.y,b.half.y),std::clamp(line.z,-b.half.z,b.half.z)};return result(b.basis.apply(line-on),a.radius,b.center+b.basis.apply(on));}
 if(a.kind==Kind::cylinder&&upright(a)&&b.kind==Kind::box&&axis_box(b)){V p=a.center-b.center,on{std::clamp(p.x,-b.half.x,b.half.x),std::clamp(p.y,-b.half.y,b.half.y),std::clamp(p.z,-b.half.z,b.half.z)};V radial{p.x-on.x,0,p.z-on.z};double length=radial.length(),vertical=std::max(0.,std::abs(p.y)-a.height*.5-b.half.y);V gap=radial.unit({1,0,0})*std::max(0.,length-a.radius)+V{0,p.y>=0?vertical:-vertical,0};return result(gap,0,b.center+on);}
 if(upright(a)&&upright(b)&&b.kind==Kind::cylinder&&(a.kind==Kind::cylinder||round)){V delta=a.center-b.center,radial{delta.x,0,delta.z};double r=a.kind==Kind::cylinder?a.radius:0,half=a.kind==Kind::sphere?0:a.kind==Kind::capsule?std::max(0.,a.height*.5-a.radius):a.height*.5;
  double hgap=std::max(0.,radial.length()-b.radius-r),vgap=std::max(0.,std::abs(delta.y)-half-b.height*.5);V gap=radial.unit({1,0,0})*hgap+V{0,delta.y>=0?vgap:-vgap,0};V on=b.center+radial.unit({1,0,0})*b.radius;on.y=std::clamp(a.center.y,b.center.y-b.height*.5,b.center.y+b.height*.5);return result(gap,a.kind==Kind::cylinder?0:a.radius,on);}
 return false;
}
inline Distance distance(const Shape &a,const Shape &b,Counters &stats){
 Distance fast;if(fast_distance(a,b,fast))return fast;
 stats.gjk++;V d=a.center-b.center;if(d.length2()<1e-12)d={1,.3,.2};auto support=[&](V dir){V av=a.support(dir),bv=b.support(-dir);return Point{av-bv,av,bv};};
 std::array<Point,4> simplex{};int size=1;simplex[0]=support(-d);V witness=simplex[0].b,v=simplex[0].v,last=d.unit();
 for(int i=0;i<80;i++){
  stats.iterations++;double sq=v.length2();if(sq<1e-16)return{0,last,witness,true};last=v.unit();Point point=support(-v);
  if(sq-v.dot(point.v)<=1e-8*std::max(1.,sq))return{std::sqrt(sq),last,witness,true};
  bool duplicate=false;for(int k=0;k<size;k++)if((simplex[k].v-point.v).length2()<1e-20)duplicate=true;if(duplicate)return{std::sqrt(sq),last,witness,true};
  if(size>=4){stats.unresolved++;return{v.length(),last,witness,false};}
  simplex[size++]=point;v=reduce(simplex,size,witness);
  if(size==0)break;
 }
 stats.unresolved++;return{v.length(),last,witness,false};
}
// Conservative initial-overlap escape among geometric/support directions.
// This is deliberately reported as a prototype recovery (not general EPA).
inline std::pair<V,double> recovery_axis(const Shape&a,const Shape&b){
 std::array<V,11> axes{{{1,0,0},{0,1,0},{0,0,1},(a.center-b.center).unit()}};int axis_count=4;
 for(const Shape *s:{&a,&b}){axes[axis_count++]=s->basis.x;axes[axis_count++]=s->basis.y;axes[axis_count++]=s->basis.z;}
 if(b.kind==Kind::triangle)axes[axis_count++]=(b.vertices[1]-b.vertices[0]).cross(b.vertices[2]-b.vertices[0]).unit();
 double best=infinity;V normal{0,1,0};for(int i=0;i<axis_count;i++)for(double sign:{-1.,1.}){V axis=axes[i];V n=axis*sign;double depth=b.support(n).dot(n)-a.support(-n).dot(n);if(depth<best){best=depth;normal=n;}}return{normal,std::max(0.,best)};
}
inline Hit sweep_one(Shape a,const Shape&b,V delta,double skin,Counters &stats,bool blocking_only=false){
 Hit h;double t=0;V relative=delta-b.motion;V last{};
 for(int i=0;i<64;i++){
  stats.advances++;Shape moved=a;moved.center=a.center+relative*t;Distance d=distance(moved,b,stats);h.converged&=d.converged;
  if(!d.converged){h.hit=true;h.fraction=t;h.normal=d.normal;h.id=b.id;return h;} // never silently clear an unresolved sweep
  if(d.distance<=skin+2e-5){
   V n=d.normal;double depth=0;
   if(t==0&&d.distance<1e-8){auto recovered=recovery_axis(moved,b);n=recovered.first;depth=recovered.second;}
   else if(last.length2()>.1)n=last;
   if(blocking_only&&t==0&&depth<=1e-6&&n.dot(relative)>=-1e-9)return h;
   h.hit=true;h.fraction=t;h.normal=n;h.point=d.point+b.motion*t;h.penetration=depth;h.id=b.id;return h;
  }
  double closing=-d.normal.dot(relative);if(closing<=1e-12)return h;
  double advance=(d.distance-skin)/closing;if(advance<1e-10){h.hit=true;h.fraction=t;h.normal=d.normal;h.id=b.id;return h;}
  t+=advance;last=d.normal;if(t>1)return h;
 }
 stats.unresolved++;h.hit=true;h.converged=false;h.fraction=t;h.normal=last;h.id=b.id;return h;
}
inline Hit ray_one(const Shape&s,V start,V delta){
 Hit h;h.id=s.id;
 if(s.kind==Kind::triangle){V e1=s.vertices[1]-s.vertices[0],e2=s.vertices[2]-s.vertices[0],p=delta.cross(e2);double det=e1.dot(p);if(std::abs(det)<1e-14)return h;V q=start-s.vertices[0];double u=q.dot(p)/det;if(u< -1e-10||u>1+1e-10)return h;V r=q.cross(e1);double v=delta.dot(r)/det,t=e2.dot(r)/det;if(v< -1e-10||u+v>1+1e-10||t<0||t>1)return h;h.hit=true;h.fraction=t;h.normal=e1.cross(e2).unit();if(h.normal.dot(delta)>0)h.normal=-h.normal;h.point=start+delta*t;return h;}
 V p=s.basis.inverse(start-s.center),d=s.basis.inverse(delta),normal{};double best=infinity;
 if(s.kind==Kind::box){double near=0,far=1;bool inside=true;for(int i=0;i<3;i++){double v=p.at(i),speed=d.at(i),extent=s.half.at(i);inside&=std::abs(v)<=extent;if(std::abs(speed)<1e-14){if(std::abs(v)>extent)return h;}else{double n=(-extent-v)/speed,f=(extent-v)/speed;V axis{};if(i==0)axis.x=-1;if(i==1)axis.y=-1;if(i==2)axis.z=-1;if(n>f){std::swap(n,f);axis=-axis;}if(n>near){near=n;normal=axis;}far=std::min(far,f);if(near>far)return h;}}best=near;if(inside)normal={};}
 else if(s.kind==Kind::cylinder){double r=s.radius,half=s.height*.5;if(p.x*p.x+p.z*p.z<=r*r&&std::abs(p.y)<=half){best=0;normal={};}else{
  double a=d.x*d.x+d.z*d.z,b=p.x*d.x+p.z*d.z,c=p.x*p.x+p.z*p.z-r*r,disc=b*b-a*c;
  if(a>1e-16&&disc>=0)for(double sign:{-1.,1.}){double t=(-b+sign*std::sqrt(disc))/a;V at=p+d*t;if(t>=0&&t<=1&&std::abs(at.y)<=half+1e-9&&t<best){best=t;normal=V{at.x,0,at.z}.unit();}}
  if(std::abs(d.y)>1e-14)for(double sign:{-1.,1.}){double t=(sign*half-p.y)/d.y;V at=p+d*t;if(t>=0&&t<=1&&at.x*at.x+at.z*at.z<=r*r+1e-9&&t<best){best=t;normal={0,sign,0};}}
 }}else if(s.kind==Kind::sphere||s.kind==Kind::capsule){
  double r=s.radius,half=s.kind==Kind::capsule?std::max(0.,s.height*.5-r):0;
  double outside=std::max(0.,std::abs(p.y)-half);
  if(p.x*p.x+p.z*p.z+outside*outside<=r*r){best=0;normal={};}
  else {
   for(double sign:{-1.,1.}){V center{0,sign*half,0},offset=p-center;double aa=d.length2(),bb=offset.dot(d),cc=offset.length2()-r*r,disc=bb*bb-aa*cc;
    if(aa>1e-20&&disc>=0){double t=(-bb-std::sqrt(disc))/aa;V at=p+d*t;if(t>=0&&t<=1&&(half==0||at.y*sign>=half)&&t<best){best=t;normal=(at-center).unit();}}}
   double aa=d.x*d.x+d.z*d.z,bb=p.x*d.x+p.z*d.z,cc=p.x*p.x+p.z*p.z-r*r,disc=bb*bb-aa*cc;
   if(half>0&&aa>1e-20&&disc>=0){double t=(-bb-std::sqrt(disc))/aa;V at=p+d*t;if(t>=0&&t<=1&&std::abs(at.y)<=half&&t<best){best=t;normal=V{at.x,0,at.z}.unit();}}
  }
 }else return h;
 if(best<=1){h.hit=true;h.fraction=best;h.normal=s.basis.apply(normal);h.point=start+delta*best;}return h;
}
struct Node {Bounds bounds;int left=-1,right=-1,begin=0,end=0;};
struct World {
 std::vector<Shape> objects;std::vector<Bounds> object_bounds;std::vector<int> order;std::vector<Node> nodes;
 bool diagonal_ad=false;int width=0,depth=0;double spacing=1;V origin{};std::vector<float> heights;
 static constexpr int tile_side=16;int tiles_x=0,tiles_z=0;std::vector<Bounds> tiles;
 int build_node(int begin,int end){int id=int(nodes.size());nodes.push_back({});Bounds b;for(int i=begin;i<end;i++){Bounds bb=object_bounds[order[i]];b.add(bb);}nodes[id].bounds=b;nodes[id].begin=begin;nodes[id].end=end;if(end-begin>8){V size=b.hi-b.lo;int axis=size.x>size.y?(size.x>size.z?0:2):(size.y>size.z?1:2),mid=(begin+end)/2;std::nth_element(order.begin()+begin,order.begin()+mid,order.begin()+end,[&](int a,int c){return objects[a].center.at(axis)<objects[c].center.at(axis);});int l=build_node(begin,mid),r=build_node(mid,end);nodes[id].left=l;nodes[id].right=r;}return id;}
 void build(){object_bounds.clear();for(const Shape&s:objects){Bounds b=s.bounds();b.add(Bounds{b.lo+s.motion,b.hi+s.motion});object_bounds.push_back(b);}
 order.resize(objects.size());std::iota(order.begin(),order.end(),0);nodes.clear();if(!order.empty())build_node(0,int(order.size()));tiles.clear();tiles_x=(width-1+tile_side-1)/tile_side;tiles_z=(depth-1+tile_side-1)/tile_side;for(int tz=0;tz<tiles_z;tz++)for(int tx=0;tx<tiles_x;tx++){Bounds b;for(int z=tz*tile_side;z<=std::min(depth-1,(tz+1)*tile_side);z++)for(int x=tx*tile_side;x<=std::min(width-1,(tx+1)*tile_side);x++)b.add(vertex(x,z));tiles.push_back(b);}}
 V vertex(int x,int z)const{return{origin.x+x*spacing,origin.y+heights[size_t(z)*width+x],origin.z+z*spacing};}
 template<class F>void visit(V start,V delta,V expand,uint32_t mask,int exclude,Counters&stats,F fn)const{
  if(!nodes.empty()){std::array<int,128> pending{};int pending_count=1;while(pending_count>0){int n=pending[--pending_count];stats.nodes++;if(!nodes[n].bounds.segment(start,delta,expand))continue;if(nodes[n].left>=0){pending[pending_count++]=nodes[n].left;pending[pending_count++]=nodes[n].right;}else for(int i=nodes[n].begin;i<nodes[n].end;i++){const Shape &s=objects[order[i]];if(s.id==exclude||!(s.mask&mask))continue;const Bounds &b=object_bounds[order[i]];if(!b.segment(start,delta,expand))continue;stats.candidates++;fn(s);}}}
  if(!(mask&1)||exclude==1||width<2||depth<2)return;
  auto cell=[&](double coordinate,double offset,int count){return int(std::clamp(std::floor((coordinate-offset)/spacing),0.,double(count-2)));};
  int x0=cell(std::min(start.x,start.x+delta.x)-expand.x,origin.x,width),x1=cell(std::max(start.x,start.x+delta.x)+expand.x,origin.x,width);
  int z0=cell(std::min(start.z,start.z+delta.z)-expand.z,origin.z,depth),z1=cell(std::max(start.z,start.z+delta.z)+expand.z,origin.z,depth);
  for(int tz=z0/tile_side;tz<=z1/tile_side;tz++)for(int tx=x0/tile_side;tx<=x1/tile_side;tx++){
   stats.nodes++;if(!tiles[size_t(tz)*tiles_x+tx].segment(start,delta,expand))continue;
   for(int z=std::max(z0,tz*tile_side);z<=std::min(z1,(tz+1)*tile_side-1);z++)for(int x=std::max(x0,tx*tile_side);x<=std::min(x1,(tx+1)*tile_side-1);x++){
    V a=vertex(x,z),b=vertex(x+1,z),c=vertex(x,z+1),d=vertex(x+1,z+1);
    std::array<std::array<V,3>,2> faces=diagonal_ad?std::array<std::array<V,3>,2>{{{a,d,b},{a,c,d}}}:std::array<std::array<V,3>,2>{{{a,c,b},{b,c,d}}};
    for(auto tri:faces){Shape s;s.kind=Kind::triangle;s.id=1;s.center=(tri[0]+tri[1]+tri[2])/3;s.vertices=tri;if(!s.bounds().segment(start,delta,expand))continue;stats.triangles++;fn(s);}
   }
  }
 }
 Hit ray(V start,V delta,uint32_t mask,int exclude,Counters&stats)const{Hit best;if(!start.finite()||!delta.finite()) {best.converged=false;return best;}visit(start,delta,{},mask,exclude,stats,[&](const Shape&s){Hit h=ray_one(s,start,delta);if(h.hit&&(!best.hit||h.fraction<best.fraction-1e-9||(std::abs(h.fraction-best.fraction)<1e-9&&h.id<best.id)))best=h;});return best;}
 Hit sweep(const Shape &shape,V delta,double skin,uint32_t mask,int exclude,Counters&stats,bool blocking_only=false)const{Hit best;if(!shape.center.finite()||!delta.finite()||!std::isfinite(skin)||skin<0){best.converged=false;return best;}V expand=shape.bounds().half()+V{skin,skin,skin};visit(shape.center,delta,expand,mask,exclude,stats,[&](const Shape&s){Hit h=sweep_one(shape,s,delta,skin,stats,blocking_only);best.converged&=h.converged;if(h.hit&&(!best.hit||h.fraction<best.fraction-1e-9||(std::abs(h.fraction-best.fraction)<1e-9&&h.id<best.id))){bool valid=best.converged;best=h;best.converged&=valid;}});return best;}
};
struct Move {V position{},velocity{};bool grounded=false,stepped=false,converged=true;int support=-1;int contacts=0;};
inline Move move_character(const World&w,V feet,V velocity,double dt,double radius,double height,int exclude,Counters&stats,bool stairs=true){
 Move out;out.position=feet;out.velocity=velocity;Shape body;body.kind=Kind::cylinder;body.radius=radius;body.height=height;constexpr double skin=.001;
 auto at=[&](V pos){body.center=pos+V{0,height*.5+.005,0};return body;};
 // Initial recovery is bounded and independent of zero requested motion.
 for(int i=0;i<4;i++){Hit h=w.sweep(at(out.position),{},0,3,exclude,stats,true);out.converged&=h.converged;if(!h.hit||h.penetration<1e-7)break;stats.recoveries++;out.position=out.position+h.normal*(h.penetration+skin);}
 V motion=velocity*dt;Hit floor=w.sweep(at(out.position),{0,-.07,0},skin,3,exclude,stats,true);out.converged&=floor.converged;bool supported=floor.hit&&floor.normal.y>=.7;
 if(stairs&&supported&&velocity.y<=0){V horizontal{motion.x,0,motion.z};Hit obstacle=w.sweep(at(out.position),horizontal,skin,3,exclude,stats,true);
  out.converged&=obstacle.converged;
  if(obstacle.hit&&obstacle.normal.dot(horizontal)<-1e-8){double step=.5625;Hit ceiling=w.sweep(at(out.position),{0,step,0},skin,3,exclude,stats,true);out.converged&=ceiling.converged;V raised=out.position+V{0,step*(ceiling.hit?ceiling.fraction:1),0};Hit across=w.sweep(at(raised),horizontal,skin,3,exclude,stats,true);
   out.converged&=across.converged;
   if(!across.hit){raised=raised+horizontal;Hit land=w.sweep(at(raised),{0,-step-.05,0},skin,3,exclude,stats,true);out.converged&=land.converged;double y=raised.y-(step+.05)*land.fraction;
    if(land.hit&&land.normal.y>=.7&&y>out.position.y+1e-5&&y<=out.position.y+step+.001){out.position={raised.x,y,raised.z};out.velocity.y=0;out.grounded=true;out.stepped=true;out.support=land.id;return out;}}}
 }
 for(int i=0;i<6&&motion.length2()>1e-16;i++){
  Hit h=w.sweep(at(out.position),motion,skin,3,exclude,stats,true);out.converged&=h.converged;
  if(!h.hit){out.position=out.position+motion;break;}
  out.contacts++;out.position=out.position+motion*std::max(0.,h.fraction);motion=motion*(1-h.fraction);
  double into=motion.dot(h.normal);if(into<0)motion=motion-h.normal*into;
  double vinto=out.velocity.dot(h.normal);if(vinto<0)out.velocity=out.velocity-h.normal*vinto;
  if(h.normal.y>=.7){out.grounded=true;out.support=h.id;}
  if(h.fraction<1e-9&&into>=-1e-10)break;
 }
 if(velocity.y<=0){Hit snap=w.sweep(at(out.position),{0,-.0625,0},skin,3,exclude,stats,true);out.converged&=snap.converged;if(snap.hit&&snap.normal.y>=.7){out.position.y-=.0625*snap.fraction;out.velocity.y=0;out.grounded=true;out.support=snap.id;}}
 return out;
}
} // namespace cqcollision
