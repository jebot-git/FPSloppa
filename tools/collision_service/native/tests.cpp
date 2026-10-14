#include "collision.hpp"
#include <iostream>
#include <random>
using namespace cqcollision;
int checks=0,failures=0;
void check(bool ok,const char*label){checks++;if(!ok){failures++;std::cerr<<"FAIL "<<label<<"\n";}}
Shape box(int id,V center,V half){Shape s;s.id=id;s.center=center;s.half=half;return s;}
Shape cylinder(int id,V center,double radius=.3,double height=1.65){Shape s;s.kind=Kind::cylinder;s.id=id;s.center=center;s.radius=radius;s.height=height;return s;}
int main(){
 World w;w.objects.push_back(box(10,{0,-.5,0},{20,.5,20}));w.objects.push_back(box(11,{2,2,0},{.08,2,8}));w.build();Counters stats;
 auto h=w.ray({0,1,0},{4,0,0},1,-1,stats);check(h.hit&&h.id==11&&std::abs(h.fraction-.48)<1e-9,"thin-wall ray");
 h=w.ray({0,1,0},{0,-2,0},1,-1,stats);check(h.hit&&h.id==10&&h.normal.y>.99,"ground ray");check(!w.ray({0,1,0},{0,3,0},1,-1,stats).hit,"clear ray");check(!w.ray({0,1,0},{4,0,0},2,-1,stats).hit,"collision layer filter");check(!w.ray({0,1,0},{4,0,0},1,11,stats).hit,"excluded shape");
 Shape body=cylinder(100,{0,.83,0});h=w.sweep(body,{10,0,0},.001,1,-1,stats);check(h.hit&&h.id==11&&std::abs(h.fraction-.1619)<.0003,"cylinder CCD does not cross thin wall");check(h.converged,"cylinder CCD converges");
 body.center={0,2,0};h=w.sweep(body,{0,-3,0},.001,1,-1,stats);check(h.hit&&h.normal.y>.99&&std::abs(h.fraction-(2-.825-.001)/3)<.001,"flat-ended cylinder floor sweep");
 Shape sphere;sphere.kind=Kind::sphere;sphere.radius=.1;sphere.center={-5,1,0};h=w.sweep(sphere,{40,0,0},.001,1,-1,stats);check(h.hit&&h.id==11&&h.fraction<.18,"fast ordnance sphere sweep");
 Shape cap;cap.kind=Kind::capsule;cap.radius=.3;cap.height=1.7;cap.center={0,2,0};h=w.sweep(cap,{0,-3,0},.001,1,-1,stats);check(h.hit&&std::abs(h.fraction-(2-.85-.001)/3)<.002,"clearance capsule support");
 auto move=move_character(w,{0,.01,0},{10,-.2,2},.5,.3,1.65,-1,stats,false);check(move.position.x<=1.622&&move.position.z>.9,"wall slide preserves tangent");check(move.grounded&&move.position.y>=-.01,"flat ground support");
 move=move_character(w,{0,-.1,0},{0,0,0},1./30,.3,1.65,-1,stats,false);check(move.position.y>=-.006,"zero-motion penetration recovery");
 World stairs;stairs.objects.push_back(box(10,{0,-.5,0},{20,.5,20}));stairs.objects.push_back(box(12,{0,.1,-1},{2,.1,.4}));stairs.build();move=move_character(stairs,{0,.001,-.2},{0,-.2,-3},.2,.3,1.65,-1,stats);check(move.stepped&&move.position.y>.18&&move.position.z<-.7,"step-up onto legal stair");
 stairs.objects[1].center.y=.4;stairs.objects[1].half.y=.4;stairs.build();move=move_character(stairs,{0,.001,-.2},{0,-.2,-3},.2,.3,1.65,-1,stats);check(!move.stepped&&move.position.z>-.5,"over-height stair blocked");
 World terrain;terrain.width=3;terrain.depth=3;terrain.spacing=1;terrain.origin={-1,0,-1};terrain.heights={0,0,0,0,1,0,0,0,0};terrain.build();h=terrain.ray({0,3,0},{0,-5,0},1,-1,stats);check(h.hit&&std::abs(h.point.y-1)<1e-8,"terrain peak ray");
 body.center={0,3,0};h=terrain.sweep(body,{0,-4,0},.001,1,-1,stats);check(h.hit&&h.fraction<.6,"finite hull terrain sweep");
 World people;auto person=cylinder(22,{2,.825,0});person.mask=2;person.motion={-4,0,0};people.objects.push_back(person);people.build();body.center={-2,.825,0};h=people.sweep(body,{4,0,0},.001,2,-1,stats);check(h.hit&&std::abs(h.fraction-.424875)<.001,"relative-motion crossing cylinders");
 World stack;person=cylinder(22,{0,.825,0});person.mask=2;stack.objects.push_back(person);stack.build();body.center={0,3,0};h=stack.sweep(body,{0,-3,0},.001,2,-1,stats);check(h.hit&&h.normal.y>.99&&std::abs(h.fraction-.174667)<.002,"flat cylinder can support another player");
 // Regression contracts beyond the seeded real-map oracle.
 check(!terrain.ray({0,3,0},{0,-5,0},1,1,stats).hit,"terrain stable ID exclusion");
 h=terrain.ray({0,-1,0},{0,4,0},1,-1,stats);check(h.hit&&h.normal.y<0,"two-sided terrain exit is explicit prototype policy");
 check(!terrain.ray({1e100,3,1e100},{1,0,0},1,-1,stats).hit,"large finite coordinates do not overflow cell indexing");
 check(!w.sweep(body,{1,0,0},NAN,1,-1,stats).converged,"nonfinite sweep skin rejected");
 World round_world;sphere.id=40;sphere.radius=.5;sphere.center={0,2,0};round_world.objects.push_back(sphere);
 cap.id=41;cap.center={3,2,0};round_world.objects.push_back(cap);round_world.build();
 h=round_world.ray({-2,2,0},{4,0,0},1,-1,stats);check(h.hit&&h.id==40&&std::abs(h.fraction-.375)<1e-9,"sphere ray earliest entry");
 h=round_world.ray({3,4,0},{0,-4,0},1,-1,stats);check(h.hit&&h.id==41&&std::abs(h.fraction-.2875)<1e-9,"capsule ray rounded top");
 h=round_world.ray({1,2,0},{4,0,0},1,-1,stats);check(h.hit&&h.id==41&&std::abs(h.fraction-.425)<1e-9,"capsule ray barrel");
 h=round_world.ray({0,2,0},{1,0,0},1,-1,stats);check(h.hit&&h.fraction==0&&h.normal.length2()==0,"round ray initial overlap");
 World bridge;auto obb=box(42,{0,1,0},{3,.2,.3});double theta=.63;
 obb.basis={{std::cos(theta),0,-std::sin(theta)},{0,1,0},{std::sin(theta),0,std::cos(theta)}};bridge.objects.push_back(obb);bridge.build();
 h=bridge.ray({0,3,0},{0,-4,0},1,-1,stats);check(h.hit&&std::abs(h.fraction-.45)<1e-9&&h.normal.y>.99,"rotated bridge ray support");
 body.center={0,3,0};h=bridge.sweep(body,{0,-4,0},.001,1,-1,stats);check(h.hit&&h.converged&&h.normal.y>.99&&std::abs(h.fraction-.2435)<.002,"rotated bridge cylinder support");
 World room;room.objects={box(50,{0,-.5,0},{20,.5,20}),box(51,{2,1,0},{.1,2,8}),box(52,{0,1,2},{8,2,.1}),box(53,{0,2.1,0},{1,.1,1})};room.build();
 move=move_character(room,{0,.001,0},{20,-.2,20},.2,.3,1.65,-1,stats,false);check(move.converged&&move.position.x<1.602&&move.position.z<1.602,"two-wall corner blocks diagonal tunnelling");
 move=move_character(room,{0,.001,0},{0,10,0},.2,.3,1.65,-1,stats,false);check(move.converged&&move.position.y<.346&&move.velocity.y<=1e-5,"jump cannot pass low ceiling");
 World tie;tie.objects={box(99,{2,1,0},{.1,2,2}),box(60,{2,1,0},{.1,2,2})};tie.build();
 h=tie.ray({0,1,0},{4,0,0},1,-1,stats);check(h.hit&&h.id==60,"equal-fraction hits use stable ID ordering");
 std::mt19937 rng(93713);std::uniform_real_distribution<double>d(-8,8);
 for(int i=0;i<500;i++){V p{d(rng),3+d(rng)*.1,d(rng)},delta{d(rng),-6,d(rng)};auto ray=w.ray(p,delta,1,-1,stats);if(ray.hit){Shape point;point.kind=Kind::sphere;point.radius=.00001;point.center=p;auto swept=w.sweep(point,delta,0,1,-1,stats);check(swept.hit&&std::abs(swept.fraction-ray.fraction)<.002,"point sweep matches analytic ray");}}
 // Shared immutable world, private per-job state, deterministic batch ordering.
 std::array<double,64> serial{},parallel{};for(int i=0;i<64;i++){Counters local;serial[i]=w.ray({i*.01,2,0},{4,-2,0},1,-1,local).fraction;}
 std::vector<std::thread> workers;for(int t=0;t<4;t++)workers.emplace_back([&,t]{for(int i=t;i<64;i+=4){Counters local;parallel[i]=w.ray({i*.01,2,0},{4,-2,0},1,-1,local).fraction;}});for(auto&t:workers)t.join();check(serial==parallel,"concurrent read-only queries match stable serial results");
 check(!w.ray({NAN,0,0},{1,0,0},1,-1,stats).converged,"nonfinite ray rejected");
 std::cout<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"gjk_calls\":"<<stats.gjk<<",\"unresolved\":"<<stats.unresolved<<"}\n";return failures?1:0;
}
