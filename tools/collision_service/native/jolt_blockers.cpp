#define CQ_JOLT_BACKEND
#define CQ_NO_SUITE_MAIN
#include "suite.cpp"
#include "disputed_cases.hpp"
#include <iomanip>
#include <Jolt/Physics/Collision/Shape/StaticCompoundShape.h>
int checks=0,failures=0;
void check(bool ok,const char*name){checks++;if(!ok){failures++;std::cerr<<"FAIL "<<name<<'\n';}}
Shape box(int id,V p,V half){Shape s;s.id=id;s.center=p;s.half=half;return s;}
Query actor(V p,V velocity,double height=1.65){Query q{};q.shape.kind=Kind(5);q.shape.center=p;q.shape.height=height;q.shape.radius=.3;q.delta=velocity;return q;}
int main(){
 // Independent analytic distances for the five disputed primitive fixtures.
 for(auto fixture:disputed_cases()){
  Shape target=fixture.first;Query q=fixture.second;World w;w.objects={target};JoltBackend jolt(w,{q});auto result=jolt.execute(q,0,0);double expected=1;
  if(int(q.shape.kind)==0){
   V p=q.shape.center-target.center;double t=-(p.x*q.delta.x+p.z*q.delta.z)/(q.delta.x*q.delta.x+q.delta.z*q.delta.z);V at=p+q.delta*t;
   check(std::hypot(at.x,at.z)>target.radius,"disputed ray is analytically outside trunk");check(!result.hit.hit,"precise ray omits the false grazing contact");
   // Repeat around the tangency boundary, including long segments and translation.
   for(double clearance:{-.001,-.0001,.0001,.001})for(double length:{40.,400.,4000.}){
    V start=target.center+V{length*.5,0,target.radius+clearance};Counters stats;
    auto hit=jolt.ray(start,{-length,0,0},1,-1,stats);check(hit.hit==(clearance<0),"precision cylinder keeps both grazing hits and misses");
   }
  }else{
   if(target.id==1251||target.id==1290){
    check(std::abs(q.shape.center.z-target.center.z)>target.radius+q.shape.radius,"disputed sphere analytically clears nominal trunk");
    check(!result.hit.hit,"nominal radius and tight tolerance avoid the grazing false contact");continue;
   }
   if(target.kind==Kind::cylinder){V p=q.shape.center-target.center;double radius=target.radius+q.shape.radius;double chord=std::sqrt(radius*radius-p.z*p.z);expected=(p.x-chord)/(-q.delta.x);}
   else expected=(q.shape.center.x-target.center.x-target.half.x-q.shape.radius)/(-q.delta.x);
   check(result.hit.hit&&std::abs(result.hit.fraction-expected)*q.delta.length()<.001,"disputed cast matches independent analytic surface within 1 mm");
  }
 }
 // Ray sidedness is a gameplay query policy; movement still blocks both sides.
 {
  World w;w.width=5;w.depth=5;w.heights.assign(25,0);w.origin={-2,0,-2};JoltBackend jolt(w,{});Counters stats;
  check(!jolt.ray({0,-1,0},{0,2,0},1,-1,stats).hit,"ground underside ray omitted");check(jolt.ray({0,1,0},{0,-2,0},1,-1,stats).hit,"ground front face still blocks fire");
  Shape body;body.kind=Kind::cylinder;body.center={0,-2,0};auto shape=cqjolt::make_shape(body);
  check(jolt.sweep(shape,body,{0,4,0},0,1,-1,stats).hit,"body sweep keeps terrain backface collision");
 }
 // Multi-tick CS stair contract: legal rise, over-height rejection and low ceiling.
 for(double rise:{.2,.55,.8})for(bool ceiling:{false,true}){
  World w;w.objects={box(10,{0,-.5,0},{8,.5,8}),box(11,{0,rise*.5,-1},{2,rise*.5,.4})};
  if(ceiling)w.objects.push_back(box(12,{0,2.,-.7},{2,.1,2}));
  Query q=actor({0,-.004,-.1},{0,-.2,-3});JoltOptions options;options.stair_height=.5625;JoltBackend jolt(w,{q},options);double peak=q.shape.center.y;int steps=0;
  for(int tick=0;tick<25;tick++){auto r=jolt.execute(q,0,0);q.shape.center=r.move.position;peak=std::max(peak,q.shape.center.y);steps+=r.move.stepped;check(r.move.converged,"stair sequence does not overflow contact buffer");}
  std::cerr<<"STAIR rise="<<rise<<" ceiling="<<ceiling<<" peak="<<peak<<" z="<<q.shape.center.z<<" steps="<<steps<<'\n';
  if(rise<=.5625&&(!ceiling||rise<.3))check(steps>0&&peak>rise-.02&&q.shape.center.z<-1.6,"legal stairs crossed including clipped headroom");
  else check(q.shape.center.z>-.35&&peak<.1,"over-height or insufficient-headroom stair remains blocked");
 }
 // Authoring alternative: keep 16 visual treads, use one thin ramp collider.
 // 3.2 m rise / 8 m run is the actual architecture.gd flight (21.8 degrees).
 for(int people:{32,64}){
  World w;w.objects={box(1,{4,-.5,people*1.5},{30,.5,people*2.})};std::vector<Query> queries;
  double theta=std::atan(.4),length=std::hypot(8.,3.2);V normal{-std::sin(theta),std::cos(theta),0};
  for(int i=0;i<people;i++){
   auto ramp=box(100+i*2,V{4,1.6,i*3.}-normal*.1,{length*.5,.1,1.2});ramp.basis={{std::cos(theta),std::sin(theta),0},normal,{0,0,1}};
   w.objects.push_back(ramp);w.objects.push_back(box(101+i*2,{10,3.1,i*3.},{2,.1,1.2}));queries.push_back(actor({-1,-.004,i*3.},{3,-.2,0}));
  }
  JoltBackend jolt(w,queries);std::vector<double> milliseconds;double maximum_lift=0;bool reached=true,returned=true,converged=true;
  for(int tick=0;tick<240;tick++){
   auto began=Clock::now();
   for(int i=0;i<people;i++){
    auto&q=queries[size_t(i)];q.delta.x=tick<120?3:-3;auto r=jolt.execute(q,size_t(i),0);q.shape.center=r.move.position;
    converged&=r.move.converged;
    if(tick==119)reached&=q.shape.center.x>9&&q.shape.center.y>3.17;
    if(tick==239)returned&=q.shape.center.x<-.8&&std::abs(q.shape.center.y)<.02;
    if(q.shape.center.x>.3&&q.shape.center.x<7.7)maximum_lift=std::max(maximum_lift,q.shape.center.y-q.shape.center.x*.4);
   }
   milliseconds.push_back(std::chrono::duration<double,std::milli>(Clock::now()-began).count());
  }
  check(converged,"ramp traversal does not overflow contacts");
  check(reached&&returned,"32/64 actors ascend and descend authored ramp without stair assistance");
  check(maximum_lift<.15,"finite-cylinder ramp foot lift stays below 15 cm");std::sort(milliseconds.begin(),milliseconds.end());
  std::cerr<<"RAMP people="<<people<<" ticks=240 p50_ms="<<milliseconds[120]<<" p95_ms="<<milliseconds[228]<<" maximum_foot_lift="<<maximum_lift<<'\n';
 }
 // Ramp headroom and prone traverse: a solid wedge is intentionally not used.
 {
  double theta=std::atan(.4);V normal{-std::sin(theta),std::cos(theta),0};auto ramp=box(21,V{4,1.6,0}-normal*.1,{std::hypot(8.,3.2)*.5,.1,1.2});ramp.basis={{std::cos(theta),std::sin(theta),0},normal,{0,0,1}};
  World w;w.objects={box(20,{4,-.5,0},{30,.5,4}),ramp};auto roof=ramp;roof.id=22;roof.center=roof.center+V{0,1.3,0};w.objects.push_back(roof);
  Query q=actor({1,.4+.116,0},{3,-.2,0},.65);JoltBackend jolt(w,{q});
  check(!jolt.resize_fixture(0,1.65),"ramp ceiling blocks standing");
  for(int tick=0;tick<60;tick++){auto r=jolt.execute(q,0,0);q.shape.center=r.move.position;}
  check(q.shape.center.x>5,"prone can traverse low-headroom ramp");
 }
 // Stance growth is collision tested and never raises the feet to fit a ceiling.
 {
  World w;w.objects={box(10,{0,-.5,0},{20,.5,20}),box(11,{0,1.3,0},{1,.1,1})};Query q=actor({0,-.004,0},{0,-.2,0},.65);JoltBackend jolt(w,{q});
  check(!jolt.resize_fixture(0,1.65),"stand-up blocked beneath low cover");
  check(jolt.resize_fixture(0,1.05),"crouch fits below low cover");check(jolt.resize_fixture(0,.65),"prone shrink always fits");q.delta={3,-.2,0};
  for(int tick=0;tick<30;tick++){auto r=jolt.execute(q,0,0);q.shape.center=r.move.position;}
  check(q.shape.center.x>2.8&&std::abs(q.shape.center.y)<.02,"prone traverses low cover without foot lift");check(jolt.resize_fixture(0,1.65),"standing restored after leaving cover");
 }
 // Slope rejection cannot be omitted in a mountainous map.
 for(double degrees:{30.,60.}){
  double theta=degrees*3.141592653589793/180;World w;auto ramp=box(10,{0,0,0},{6,.2,3});ramp.basis={{std::cos(theta),std::sin(theta),0},{-std::sin(theta),std::cos(theta),0},{0,0,1}};w.objects={ramp};
  double y=-2*std::tan(theta)+.2/std::cos(theta)+.3*std::tan(theta)-.004;Query q=actor({-2,y,0},{3,-.2,0});JoltBackend jolt(w,{q});double start=q.shape.center.x;
  for(int tick=0;tick<30;tick++){auto r=jolt.execute(q,0,0);q.shape.center=r.move.position;}
  if(degrees==30)check(q.shape.center.x>start+1,"walkable slope allows ascent");else check(q.shape.center.x<start+.1,"steep slope cannot be climbed");
 }
 // Fast jetpack/room-scale translation still requires swept solid cover.
 {
  World w;w.objects={box(10,{2,2,0},{.02,4,4})};Query q=actor({0,1,0},{300,0,0});JoltBackend jolt(w,{q});auto r=jolt.execute(q,0,0);check(r.move.position.x<1.682&&std::abs(r.move.velocity.x)<.01,"fast avatar cannot pass a 4 cm wall");
 }
 // Relative sweeps find simultaneous crossings where endpoint overlap misses.
 {
  World w;JoltBackend jolt(w,{});Shape a;a.kind=Kind::cylinder;a.center={-2,.825,0};a.id=20;Shape b=a;b.center.x=2;b.id=21;
  for(int people:{32,64})for(int pair=0;pair<people/2;pair++){
   a.center.z=b.center.z=pair*2;auto h=jolt_relative_sweep(a,b,{4,0,0},{-4,0,0});check(h.hit&&std::abs(h.fraction-.425)<.001,"relative Jolt sweep detects crossing actors");
   auto left=a.center+V{4,0,0}*h.fraction,right=b.center+V{-4,0,0}*h.fraction;check(right.x-left.x>=.599,"symmetric pair stop keeps actor order and separation");
  }
  a.center={0,3,0};b.center={0,.825,0};auto h=jolt_relative_sweep(a,b,{0,-3,0},{});check(h.hit&&h.normal.y>.99&&std::abs(h.fraction-.175)<.002,"flat player top can support another player");
 }
 // Fail closed on contact-buffer overflow, then retry with a bounded larger cap.
 {
  World w;w.objects={box(10,{0,-.5,0},{10,.5,10}),box(11,{2,1,0},{.1,2,8})};Query q=actor({1.59,-.004,0},{5,-.2,1});JoltBackend jolt(w,{q});
  jolt.fixture_character(0).SetMaxNumHits(1);auto limited=jolt.execute(q,0,0);
  check(!limited.move.converged&&(limited.move.position-q.shape.center).length()<1e-9,"contact overflow prevents committing an incomplete move");
  jolt.fixture_character(0).SetMaxNumHits(256);auto retry=jolt.execute(q,0,0);check(retry.move.converged&&retry.move.grounded,"bounded larger contact buffer resolves the same move");
 }
 // A dense connected island can use Jolt's built-in character collision checker
 // serially. Never call CharacterVsCharacterCollisionSimple concurrently.
 for(bool side_push:{true,false})for(int people:{32,64}){
  World w;w.objects={box(10,{0,-.5,0},{30,.5,30})};std::vector<Query> qs;
  for(int i=0;i<people;i++)qs.push_back(actor({(i%8-3.5)*.65,-.004,(i/8-(people/8-1)*.5)*.65},{0,-.2,0}));
  JoltOptions options;options.allow_side_push=side_push;JoltBackend jolt(w,qs,options);JPH::CharacterVsCharacterCollisionSimple collision;
  for(int i=0;i<people;i++){auto&c=jolt.fixture_character(size_t(i));collision.Add(&c);c.SetCharacterVsCharacterCollision(&collision);}
  bool converged=true;double minimum=.65;std::vector<double> frames;
  for(int tick=0;tick<90;tick++){
   auto began=Clock::now();
   for(int i=0;i<people;i++){auto&q=qs[size_t(i)];V direction=V{-q.shape.center.x,0,-q.shape.center.z}.unit({});q.delta=direction*3+V{0,-.2,0};auto result=jolt.execute(q,size_t(i),0);q.shape.center=result.move.position;converged&=result.move.converged;}
   frames.push_back(std::chrono::duration<double,std::milli>(Clock::now()-began).count());
   for(int i=0;i<people;i++)for(int j=i+1;j<people;j++){V gap=qs[size_t(i)].shape.center-qs[size_t(j)].shape.center;minimum=std::min(minimum,std::hypot(gap.x,gap.z));}
  }
  if(!side_push)check(converged&&minimum>.595,"dense CS blocking island keeps separation without side pushing");
  std::sort(frames.begin(),frames.end());std::cerr<<"ISLAND side_push="<<side_push<<" people="<<people<<" ticks=90 p50_ms="<<frames[45]<<" p95_ms="<<frames[85]<<" min_distance="<<minimum<<'\n';
  for(int i=0;i<people;i++)jolt.fixture_character(size_t(i)).SetCharacterVsCharacterCollision(nullptr);
 }
 // Player stacking and moving support cannot be removed as an optimization.
 {
  World w;w.objects={box(10,{0,-.5,0},{30,.5,30})};std::vector<Query> qs={actor({0,-.004,0},{1,-.2,0}),actor({0,1.646,0},{0,-.2,0})};JoltOptions options;options.carry_support=true;JoltBackend jolt(w,qs,options);
  JPH::CharacterVsCharacterCollisionSimple collision;for(size_t i=0;i<2;i++){collision.Add(&jolt.fixture_character(i));jolt.fixture_character(i).SetCharacterVsCharacterCollision(&collision);}
  for(int tick=0;tick<60;tick++)for(size_t i=0;i<2;i++){auto r=jolt.execute(qs[i],i,0);qs[i].shape.center=r.move.position;}
  check(std::abs(qs[1].shape.center.y-qs[0].shape.center.y-1.65)<.02,"player stack stays supported over multiple ticks");
  check(std::abs(qs[1].shape.center.x-qs[0].shape.center.x)<.08&&qs[1].shape.center.x>1.8,"upper player follows lower player's support velocity");
  for(size_t i=0;i<2;i++)jolt.fixture_character(i).SetCharacterVsCharacterCollision(nullptr);
 }
 // Existing rocket-tank hull and turret profiles remain a compound solid.
 {
  World w;w.objects={box(10,{5,3,0},{.02,3,10})};JoltBackend jolt(w,{});
  Shape hull=box(30,{0,1,0},{2.25,.85,2.4});auto id=jolt.add_kinematic_fixture(hull);
  JPH::RefConst<JPH::Shape> hull_shape=new JPH::BoxShape(JPH::Vec3(2.25f,.85f,2.4f),0),turret=new JPH::BoxShape(JPH::Vec3(1.15f,.7f,1.15f),0);
  JPH::StaticCompoundShapeSettings parts;parts.AddShape(JPH::Vec3::sZero(),JPH::Quat::sIdentity(),hull_shape,1);parts.AddShape(JPH::Vec3(0,1.58f,0),JPH::Quat::sIdentity(),turret,2);auto compound=parts.Create();check(!compound.HasError(),"vehicle compound profile builds");
  jolt.fixture_system().GetBodyInterface().SetShape(id,compound.Get(),true,JPH::EActivation::DontActivate);Counters stats;
  auto shot=jolt.ray({0,2.9,10},{0,0,-20},1,-1,stats);check(shot.hit&&shot.id==30,"vehicle turret retains ballistic cover above hull");
  auto hit=jolt.sweep(compound.Get(),hull,{20,0,0},0,1,30,stats);check(hit.hit&&hit.id==10&&std::abs(hit.fraction-.1365)<.001,"vehicle compound CCD blocks fast hull at thin wall");
  check(!jolt.ray({0,2.9,10},{0,0,-20},1,30,stats).hit,"vehicle stable ID exclusion covers all compound parts");
 }
 // Kinematic support carry is explicit: dropping it loses a required behavior.
 for(bool carry:{false,true}){
  World w;w.objects={box(99,{1000,0,0},{1,1,1})};Query q=actor({0,-.004,0},{0,-.2,0});JoltOptions options;options.carry_support=carry;JoltBackend jolt(w,{q},options);
  Shape platform=box(30,{0,-.5,0},{5,.5,5});auto id=jolt.add_kinematic_fixture(platform);auto&bodies=jolt.fixture_system().GetBodyInterface();
  bodies.SetLinearVelocity(id,JPH::Vec3(2,0,0));
  for(int tick=0;tick<30;tick++){
   bodies.SetPositionAndRotation(id,JPH::RVec3(tick*2./30,-.5,0),JPH::Quat::sIdentity(),JPH::EActivation::DontActivate);
   auto r=jolt.execute(q,0,0);q.shape.center=r.move.position;
  }
  check(carry?std::abs(q.shape.center.x-2)<.03:std::abs(q.shape.center.x)<.01,carry?"support velocity carries passenger":"negative control: support carry omitted loses platform motion");
 }
 std::cout<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<"}\n";return failures?1:0;
}
