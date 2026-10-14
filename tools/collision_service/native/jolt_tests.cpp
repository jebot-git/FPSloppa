#define CQ_JOLT_BACKEND
#define CQ_NO_SUITE_MAIN
#include "suite.cpp"
#include <random>
int checks=0,failures=0;
void check(bool ok,const char*label){checks++;if(!ok){failures++;std::cerr<<"FAIL "<<label<<'\n';}}
Shape box(int id,V p,V half){Shape s;s.id=id;s.center=p;s.half=half;return s;}
Query query(int kind,V p,V delta,double radius=.3,double height=1.65){Query q{};q.shape.kind=Kind(kind);q.shape.center=p;q.shape.radius=radius;q.shape.height=height;q.shape.mask=1;q.delta=delta;return q;}
int main(){
 {
  World w;w.objects={box(10,{0,-.5,0},{20,.5,20}),box(11,{2,2,0},{.08,2,8}),box(12,{0,2.1,0},{1,.1,1})};
  auto trunk=box(13,{-3,2,0},{});trunk.kind=Kind::cylinder;trunk.radius=.4;trunk.height=4;w.objects.push_back(trunk);
  auto bridge=box(14,{8,2,0},{2,.25,.3});double angle=.63;bridge.basis={{std::cos(angle),0,-std::sin(angle)},{0,1,0},{std::sin(angle),0,std::cos(angle)}};w.objects.push_back(bridge);
  std::vector<Query> queries={query(1,{0,.83,0},{10,0,0}),query(2,{-5,1,0},{40,0,0},.1),query(3,{0,1.2,4},{0,-3,0},.3,1.7),
   query(5,{0,.001,4},{5,-.2,2}),query(5,{0,.001,0},{0,30,0}),query(5,{0,-.1,4},{0,0,0}),query(1,{0,3,4},{0,-3,0}),
   query(2,{-5,2,0},{4,0,0},.1),query(5,{1.6,.001,4},{5,-.2,1}),query(1,{8,5,0},{0,-6,0}),query(1,{-3,5,0},{0,-5,0})};
  JoltBackend jolt(w,queries);Counters stats;
  auto h=jolt.ray({0,1,3},{4,0,0},1,-1,stats);check(h.hit&&h.id==11&&std::abs(h.fraction-.48)<1e-5,"Jolt thin-wall ray");
  check(!jolt.ray({0,1,3},{4,0,0},2,-1,stats).hit,"Jolt layer mask");check(!jolt.ray({0,1,3},{4,0,0},1,11,stats).hit,"Jolt stable ID exclusion");
  h=jolt.ray({2,1,3},{1,0,0},1,-1,stats);check(h.hit&&h.fraction==0&&h.normal.length2()==0,"Jolt solid ray starts inside");
  h=jolt.ray({-5,2,0},{4,0,0},1,-1,stats);check(h.hit&&h.id==13&&std::abs(h.fraction-.4)<1e-5,"Jolt cylinder ray");
  auto r=jolt.execute(queries[0],0,0);check(r.hit.hit&&r.hit.id==11&&std::abs(r.hit.fraction-.1619)<.0003,"Jolt cylinder high-speed CCD");
  r=jolt.execute(queries[1],1,0);check(r.hit.hit&&r.hit.id==13&&r.hit.fraction<.07,"Jolt ordnance earliest hit");
  r=jolt.execute(queries[2],2,0);check(r.hit.hit&&std::abs(r.hit.fraction-(1.2-.85-.001)/3)<.002,"Jolt capsule support sweep");
  r=jolt.execute(queries[3],3,0);check(r.move.grounded&&r.move.position.x>.16&&r.move.position.z>4.06,"Jolt supported movement");check(std::abs(r.move.velocity.y)<1e-6,"Jolt adapter outputs resolved floor velocity");
  r=jolt.execute(queries[4],4,0);check(r.move.position.y<.346&&r.move.velocity.y<=1e-5,"Jolt ceiling blocks jump and resolves velocity");
  r=jolt.execute(queries[5],5,0);check(r.move.position.y>=-.01,"Jolt zero-motion overlap recovery");
  r=jolt.execute(queries[6],6,0);check(r.hit.hit&&r.hit.normal.y>.99&&std::abs(r.hit.fraction-(3-.825-.001)/3)<.001,"Jolt cylinder has flat feet");
  r=jolt.execute(queries[7],7,0);check(r.hit.hit&&r.hit.id==13&&std::abs(r.hit.fraction-.37475)<.002,"Jolt sphere versus trunk");
  r=jolt.execute(queries[8],8,0);check(r.move.grounded&&r.move.position.x<1.622&&r.move.position.z>4.025&&std::abs(r.move.velocity.x)<.01,"Jolt wall slide returns resolved velocity and preserves tangent");
  r=jolt.execute(queries[9],9,0);check(r.hit.hit&&r.hit.id==14&&r.hit.normal.y>.99&&std::abs(r.hit.fraction-(5-2.25-.825-.001)/6)<.002,"Jolt OBB bridge supports cylinder");
  r=jolt.execute(queries[10],10,0);check(r.hit.hit&&r.hit.id==13&&r.hit.normal.y>.99,"Jolt upright cylinder supports cylinder");
  std::mt19937 rng(93713);std::uniform_real_distribution<double>d(-6,6);
  w.build();for(int i=0;i<200;i++){V p{d(rng),1,d(rng)},delta{d(rng),-2,d(rng)};Counters a,b;auto expected=w.ray(p,delta,1,-1,a);auto actual=jolt.ray(p,delta,1,-1,b);check(expected.hit==actual.hit&&(!expected.hit||std::abs(expected.fraction-actual.fraction)<1e-4),"Jolt primitive rays match independent analytic service");}
  // Repeat the same movement after resetting it, including from another thread.
  auto reference=jolt.execute(queries[3],3,0);Result threaded;std::thread worker([&]{threaded=jolt.execute(queries[3],3,1);});worker.join();
  check((reference.move.position-threaded.move.position).length()<1e-9&&(reference.move.velocity-threaded.move.velocity).length()<1e-9,"Jolt reset move is worker independent");
 }
 // Nonplanar cells expose both diagonal conventions and world coordinate mapping.
 for(bool ad:{false,true}){
  World w;w.width=5;w.depth=5;w.spacing=2;w.origin={-4,7,-4};w.diagonal_ad=ad;w.heights={0,0,0,0,0,0,1,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0};w.build();
  JoltBackend jolt(w,{});
  for(int z=0;z<4;z++)for(int x=0;x<4;x++)for(double f:{.2,.7}){V p{w.origin.x+(x+f)*2,30,w.origin.z+(z+.3)*2},delta{0,-40,0};Counters a,b;auto expected=w.ray(p,delta,1,-1,a),actual=jolt.ray(p,delta,1,-1,b);check(expected.hit&&actual.hit&&std::abs(expected.fraction-actual.fraction)*40<.001,"Jolt heightfield preserves diagonal, scale and origin");}
  Counters stats;check(!jolt.ray({0,30,0},{0,-40,0},1,1,stats).hit,"Jolt terrain ID exclusion");
 }
 std::cout<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<"}\n";return failures?1:0;
}
