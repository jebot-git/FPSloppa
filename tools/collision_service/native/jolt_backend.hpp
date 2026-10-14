#pragma once
// Direct Jolt backend for the frozen-world comparison. No Godot API calls.
#include <Jolt/Jolt.h>
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Collision/NarrowPhaseQuery.h>
#include <Jolt/Physics/Collision/RayCast.h>
#include <Jolt/Physics/Collision/CastResult.h>
#include <Jolt/Physics/Collision/ShapeCast.h>
#include <Jolt/Physics/Collision/CollisionCollectorImpl.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/CylinderShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/Collision/Shape/CapsuleShape.h>
#include <Jolt/Physics/Collision/Shape/HeightFieldShape.h>
#include <Jolt/Physics/Collision/Shape/ScaledShape.h>
#include <Jolt/Physics/Character/CharacterVirtual.h>
#include <memory>

struct JoltOptions {
 bool ray_backfaces=false,precise_cylinder_rays=true,carry_support=false,allow_side_push=false;
 double sweep_margin=0,stair_height=0,sweep_tolerance=1e-6;
 static JoltOptions environment(){JoltOptions out;
  if(auto*p=std::getenv("CQ_JOLT_RAY_BACKFACES"))out.ray_backfaces=std::string(p)!="0";
  if(auto*p=std::getenv("CQ_JOLT_PRECISE_RAYS"))out.precise_cylinder_rays=std::string(p)!="0";
  if(auto*p=std::getenv("CQ_JOLT_SWEEP_MARGIN"))out.sweep_margin=std::stod(p);
  if(auto*p=std::getenv("CQ_JOLT_SWEEP_TOLERANCE"))out.sweep_tolerance=std::stod(p);
  return out;
 }
};
namespace cqjolt {
inline JPH::Vec3 vec(V v){return JPH::Vec3(float(v.x),float(v.y),float(v.z));}
inline JPH::RVec3 position(V v){return JPH::RVec3(v.x,v.y,v.z);}
inline V value(JPH::Vec3 v){return {v.GetX(),v.GetY(),v.GetZ()};}
#ifdef JPH_DOUBLE_PRECISION
inline V value(JPH::RVec3 v){return {v.GetX(),v.GetY(),v.GetZ()};}
#endif
inline JPH::Quat rotation(Basis b){
 JPH::Mat44 m=JPH::Mat44::sIdentity();m.SetColumn3(0,vec(b.x));m.SetColumn3(1,vec(b.y));m.SetColumn3(2,vec(b.z));return m.GetQuaternion().Normalized();
}
// Count Jolt's allocator calls in addition to the shared harness's operator new.
struct Runtime {
 inline static JPH::AllocateFunction saved_allocate=nullptr;
 inline static JPH::ReallocateFunction saved_reallocate=nullptr;
 inline static JPH::AlignedAllocateFunction saved_aligned=nullptr;
 Runtime(){
  JPH::RegisterDefaultAllocator();saved_allocate=JPH::Allocate;saved_reallocate=JPH::Reallocate;saved_aligned=JPH::AlignedAllocate;
  JPH::Allocate=[](size_t n)->void*{if(count_allocations)allocations++;return saved_allocate(n);};
  JPH::Reallocate=[](void*p,size_t old_n,size_t n)->void*{if(count_allocations)allocations++;return saved_reallocate(p,old_n,n);};
  JPH::AlignedAllocate=[](size_t n,size_t align)->void*{if(count_allocations)allocations++;return saved_aligned(n,align);};
#ifdef JPH_ENABLE_ASSERTS
  JPH::AssertFailed=[](const char*expression,const char*message,const char*file,JPH::uint line)->bool{
   std::cerr<<"Jolt assertion: "<<expression<<" "<<(message?message:"")<<" at "<<file<<':'<<line<<'\n';std::abort();};
#endif
  JPH::Factory::sInstance=new JPH::Factory;JPH::RegisterTypes();
 }
 ~Runtime(){JPH::UnregisterTypes();delete JPH::Factory::sInstance;JPH::Factory::sInstance=nullptr;JPH::Allocate=saved_allocate;JPH::Reallocate=saved_reallocate;JPH::AlignedAllocate=saved_aligned;}
};
struct BroadLayers final:JPH::BroadPhaseLayerInterface {
 JPH::uint GetNumBroadPhaseLayers()const override{return 1;}
 JPH::BroadPhaseLayer GetBroadPhaseLayer(JPH::ObjectLayer)const override{return JPH::BroadPhaseLayer(0);}
};
struct BroadPairs final:JPH::ObjectVsBroadPhaseLayerFilter {bool ShouldCollide(JPH::ObjectLayer,JPH::BroadPhaseLayer)const override{return true;}};
struct LayerPairs final:JPH::ObjectLayerPairFilter {bool ShouldCollide(JPH::ObjectLayer a,JPH::ObjectLayer b)const override{return(a&b)!=0;}};
struct Layers final:JPH::ObjectLayerFilter {
 uint32_t mask;explicit Layers(uint32_t m):mask(m){}
 bool ShouldCollide(JPH::ObjectLayer layer)const override{return(layer&mask)!=0;}
};
struct Bodies final:JPH::BodyFilter {
 int exclude;Counters &stats;explicit Bodies(int e,Counters&s):exclude(e),stats(s){}
 bool ShouldCollideLocked(const JPH::Body &body)const override{stats.candidates++;return int(body.GetUserData())!=exclude;}
};
struct MoveListener final:JPH::CharacterContactListener {
 bool allow_side_push=false;
 void OnCharacterContactAdded(const JPH::CharacterVirtual*,const JPH::CharacterContact&contact,JPH::CharacterContactSettings&settings)override{if(!allow_side_push&&contact.mSurfaceNormal.GetY()<.7f)settings.mCanPushCharacter=false;settings.mCanReceiveImpulses=false;}
 void OnCharacterContactPersisted(const JPH::CharacterVirtual*c,const JPH::CharacterContact&contact,JPH::CharacterContactSettings&settings)override{OnCharacterContactAdded(c,contact,settings);}
 JPH::Vec3 resolved=JPH::Vec3::sZero();
 void OnCharacterContactSolve(const JPH::CharacterVirtual*,const JPH::CharacterVirtual*,const JPH::SubShapeID&,JPH::RVec3Arg,JPH::Vec3Arg,JPH::Vec3Arg,const JPH::PhysicsMaterial*,JPH::Vec3Arg,JPH::Vec3&velocity)override{resolved=velocity;}
 void OnContactSolve(const JPH::CharacterVirtual*,const JPH::BodyID&,const JPH::SubShapeID&,JPH::RVec3Arg,JPH::Vec3Arg,JPH::Vec3Arg,const JPH::PhysicsMaterial*,JPH::Vec3Arg,JPH::Vec3&velocity)override{resolved=velocity;}
};
inline JPH::RefConst<JPH::Shape> make_shape(const Shape&s){
 switch(s.kind){
 case Kind::box:return new JPH::BoxShape(vec(s.half),0);
 case Kind::cylinder:return new JPH::CylinderShape(float(s.height*.5),float(s.radius),0);
 case Kind::sphere:return new JPH::SphereShape(float(s.radius));
 case Kind::capsule:return new JPH::CapsuleShape(float(s.height*.5-s.radius),float(s.radius));
 default:throw std::runtime_error("unsupported Jolt primitive");
 }
}
}
// Double-precision cylinder interval test, using Jolt's actual body transform
// and dimensions. Projection form avoids cancellation in b*b - a*c.
inline V rotate_double(JPH::Quat q,V v){V axis{q.GetX(),q.GetY(),q.GetZ()};return v+axis.cross(axis.cross(v)+v*q.GetW())*2;}
inline Hit precise_cylinder(const JPH::Body&body,V start,V delta){
 const auto&shape=static_cast<const JPH::CylinderShape&>(*body.GetShape());auto inverse=body.GetRotation().Conjugated();
 V p=rotate_double(inverse,start-cqjolt::value(body.GetPosition())),d=rotate_double(inverse,delta);
 double radius=shape.GetRadius(),half=shape.GetHalfHeight(),near=0,far=1;V normal{};
 double a=d.x*d.x+d.z*d.z;
 if(a<1e-24){if(p.x*p.x+p.z*p.z>radius*radius)return {};}
 else {double middle=-(p.x*d.x+p.z*d.z)/a;V closest=p+d*middle;double gap=radius*radius-closest.x*closest.x-closest.z*closest.z;
  if(gap<0)return {};
  double extent=std::sqrt(gap/a),first=middle-extent,last=middle+extent;
  if(first>near){near=first;V at=p+d*near;normal=V{at.x,0,at.z}.unit();}far=std::min(far,last);if(near>far)return {};
 }
 if(std::abs(d.y)<1e-15){if(std::abs(p.y)>half)return {};}
 else {double first=(-half-p.y)/d.y,last=(half-p.y)/d.y;V axis{0,-1,0};if(first>last){std::swap(first,last);axis=-axis;}if(first>near){near=first;normal=axis;}far=std::min(far,last);if(near>far)return {};}
 Hit hit;hit.hit=true;hit.fraction=near;hit.id=int(body.GetUserData());hit.normal=rotate_double(body.GetRotation(),normal);hit.point=start+delta*near;return hit;
}
class JoltBackend {
 // Runtime must outlive the system, cached shapes, characters and allocators.
 cqjolt::Runtime runtime;
 JoltOptions options;
 cqjolt::BroadLayers broad_layers;cqjolt::BroadPairs broad_pairs;cqjolt::LayerPairs layer_pairs;
 JPH::PhysicsSystem system;
 std::vector<JPH::BodyID> body_ids;
 std::vector<JPH::RefConst<JPH::Shape>> query_shapes;
 std::vector<std::unique_ptr<JPH::CharacterVirtual>> characters;
 std::array<std::unique_ptr<JPH::TempAllocatorImpl>,8> scratch;
public:
 explicit JoltBackend(const World&w,const std::vector<Query>&queries,JoltOptions config=JoltOptions::environment()):options(config){
  system.Init(JPH::uint(w.objects.size()+16),64,1024,1024,broad_layers,broad_pairs,layer_pairs);system.SetGravity(JPH::Vec3::sZero());
  if(w.width>=2){
   if(w.width!=w.depth)throw std::runtime_error("Jolt suite requires a square heightfield");
   // Jolt uses the AD diagonal. Reflect a reversed-X sample array for BC.
   std::vector<float> samples(w.heights.size());
   for(int z=0;z<w.depth;z++)for(int x=0;x<w.width;x++)samples[size_t(z)*w.width+x]=w.heights[size_t(z)*w.width+(w.diagonal_ad?x:w.width-1-x)];
   JPH::HeightFieldShapeSettings settings(samples.data(),JPH::Vec3::sZero(),JPH::Vec3(float(w.spacing),1,float(w.spacing)),JPH::uint(w.width));
   settings.mBitsPerSample=16;settings.mBlockSize=2;
   auto made=settings.Create();if(made.HasError())throw std::runtime_error(made.GetError().c_str());
   JPH::RefConst<JPH::Shape> terrain=made.Get();V origin=w.origin;
   if(!w.diagonal_ad){terrain=new JPH::ScaledShape(terrain,JPH::Vec3(-1,1,1));origin.x+=(w.width-1)*w.spacing;}
   add_body(terrain,origin,{},1,1);
  }
  for(const Shape&s:w.objects){
   if(s.motion.length2()!=0)throw std::runtime_error("direct Jolt suite exports static objects only; dynamic relative sweeps are not implemented");
   if(s.mask>65535)throw std::runtime_error("Jolt suite object mask exceeds 16 bits");
   add_body(cqjolt::make_shape(s),s.center,s.basis,s.id,s.mask);
  }
  auto &bodies=system.GetBodyInterface();auto added=bodies.AddBodiesPrepare(body_ids.data(),int(body_ids.size()));
  bodies.AddBodiesFinalize(body_ids.data(),int(body_ids.size()),added,JPH::EActivation::DontActivate);system.OptimizeBroadPhase();
  for(auto&allocator:scratch)allocator=std::make_unique<JPH::TempAllocatorImpl>(2*1024*1024);
  query_shapes.resize(queries.size());characters.resize(queries.size());
  for(size_t i=0;i<queries.size();i++){
   const auto&q=queries[i];int kind=int(q.shape.kind);
   if(kind>=1&&kind<=3)query_shapes[i]=cqjolt::make_shape(q.shape);
   else if(kind==5){
    Shape hull=q.shape;hull.kind=Kind::cylinder;JPH::CharacterVirtualSettings settings;
    settings.mShape=cqjolt::make_shape(hull);settings.mShapeOffset=JPH::Vec3(0,float(hull.height*.5+.005),0);
    settings.mMaxSlopeAngle=float(std::acos(.7));settings.mCharacterPadding=.001f;settings.mCollisionTolerance=.001f;
    settings.mSupportingVolume=JPH::Plane(JPH::Vec3::sAxisY(),-.3f);
    settings.mEnhancedInternalEdgeRemoval=true;
    characters[i]=std::make_unique<JPH::CharacterVirtual>(&settings,cqjolt::position(q.shape.center),JPH::Quat::sIdentity(),0,&system);
   }
  }
 }
 ~JoltBackend(){characters.clear();auto &bodies=system.GetBodyInterface();bodies.RemoveBodies(body_ids.data(),int(body_ids.size()));bodies.DestroyBodies(body_ids.data(),int(body_ids.size()));}
 void add_body(const JPH::Shape*shape,V center,Basis basis,int id,uint32_t mask){
  JPH::BodyCreationSettings settings(shape,cqjolt::position(center),cqjolt::rotation(basis),JPH::EMotionType::Static,JPH::ObjectLayer(mask));settings.mUserData=uint64_t(id);
  auto *body=system.GetBodyInterface().CreateBody(settings);if(!body)throw std::runtime_error("Jolt body capacity exhausted");body_ids.push_back(body->GetID());
 }
 Hit ray(V start,V delta,uint32_t mask,int exclude,Counters&stats)const{
  Hit out;if(!start.finite()||!delta.finite()){out.converged=false;return out;}
  cqjolt::Layers layers(mask);cqjolt::Bodies bodies(exclude,stats);JPH::ClosestHitCollisionCollector<JPH::CastRayCollector> collector;
  JPH::RayCastSettings settings;settings.SetBackFaceMode(JPH::EBackFaceMode::CollideWithBackFaces);settings.mBackFaceModeTriangles=options.ray_backfaces?JPH::EBackFaceMode::CollideWithBackFaces:JPH::EBackFaceMode::IgnoreBackFaces;settings.mTreatConvexAsSolid=true;
  JPH::RRayCast cast(cqjolt::position(start),cqjolt::vec(delta));
  if(options.precise_cylinder_rays){
   struct PreciseCollector final:JPH::RayCastBodyCollector {
    const JPH::PhysicsSystem&system;const JPH::RRayCast&cast;const JPH::RayCastSettings&settings;cqjolt::Bodies&filter;V start,delta;Hit best;
    PreciseCollector(const JPH::PhysicsSystem&s,const JPH::RRayCast&c,const JPH::RayCastSettings&q,cqjolt::Bodies&f,V p,V d):system(s),cast(c),settings(q),filter(f),start(p),delta(d){}
    void AddHit(const JPH::BroadPhaseCastResult&candidate)override{
     JPH::BodyLockRead lock(system.GetBodyLockInterface(),candidate.mBodyID);if(!lock.Succeeded()){best.converged=false;return;}
     const auto&body=lock.GetBody();if(!filter.ShouldCollideLocked(body))return;Hit hit;
     if(body.GetShape()->GetSubType()==JPH::EShapeSubType::Cylinder)hit=precise_cylinder(body,start,delta);
     else {JPH::ClosestHitCollisionCollector<JPH::CastRayCollector> native;body.GetTransformedShape().CastRay(cast,settings,native);
      if(native.HadHit()){hit.hit=true;hit.fraction=native.mHit.mFraction;hit.id=int(body.GetUserData());hit.point=start+delta*hit.fraction;
       if(hit.fraction>0){hit.normal=cqjolt::value(body.GetWorldSpaceSurfaceNormal(native.mHit.mSubShapeID2,cast.GetPointOnRay(native.mHit.mFraction)));if(hit.normal.dot(delta)>0)hit.normal=-hit.normal;}}
     }
     if(hit.hit&&(!best.hit||hit.fraction<best.fraction-1e-9||(std::abs(hit.fraction-best.fraction)<=1e-9&&hit.id<best.id))){bool valid=best.converged;best=hit;best.converged&=valid;UpdateEarlyOutFraction(float(best.fraction)+1e-6f);}
    }
   } precise(system,cast,settings,bodies,start,delta);
   system.GetBroadPhaseQuery().CastRay(JPH::RayCast(cqjolt::vec(start),cqjolt::vec(delta)),precise,{},layers);return precise.best;
  }
  system.GetNarrowPhaseQuery().CastRay(cast,settings,collector,{},layers,bodies);
  if(collector.HadHit()){
   const auto&r=collector.mHit;JPH::BodyLockRead lock(system.GetBodyLockInterface(),r.mBodyID);
   if(!lock.Succeeded()){out.converged=false;return out;}
   out.hit=true;out.fraction=r.mFraction;out.point=start+delta*out.fraction;out.id=int(lock.GetBody().GetUserData());
   if(out.fraction>0){out.normal=cqjolt::value(lock.GetBody().GetWorldSpaceSurfaceNormal(r.mSubShapeID2,cast.GetPointOnRay(r.mFraction)));if(out.normal.dot(delta)>0)out.normal=-out.normal;}
  }
  return out;
 }
 Hit sweep(const JPH::Shape*shape,const Shape&source,V delta,double margin,uint32_t mask,int exclude,Counters&stats)const{
  Hit out;cqjolt::Layers layers(mask);cqjolt::Bodies bodies(exclude,stats);
  JPH::ShapeCastSettings settings;settings.SetBackFaceMode(JPH::EBackFaceMode::CollideWithBackFaces);
  settings.mExtraConvexRadius=float(margin);settings.mReturnDeepestPoint=true;settings.mCollisionTolerance=float(options.sweep_tolerance);
  JPH::RShapeCast cast=JPH::RShapeCast::sFromWorldTransform(shape,JPH::Vec3::sOne(),JPH::RMat44::sRotationTranslation(cqjolt::rotation(source.basis),cqjolt::position(source.center)),cqjolt::vec(delta));
  JPH::ClosestHitCollisionCollector<JPH::CastShapeCollector> collector;
  system.GetNarrowPhaseQuery().CastShape(cast,settings,cqjolt::position(source.center),collector,{},layers,bodies);
  if(collector.HadHit()){
   const auto&r=collector.mHit;out.hit=true;out.fraction=r.mFraction;out.normal=-cqjolt::value(r.mPenetrationAxis.NormalizedOr(JPH::Vec3::sAxisY()));
   out.penetration=r.mPenetrationDepth;out.point=source.center+cqjolt::value(r.mContactPointOn2);
   out.id=int(system.GetBodyInterface().GetUserData(r.mBodyID2));
  }
  return out;
 }
 // Test-only dynamic fixture access. Mutations must occur between query phases.
 JPH::PhysicsSystem& fixture_system(){return system;}
 JPH::CharacterVirtual& fixture_character(size_t i){return *characters.at(i);}
 JPH::BodyID add_kinematic_fixture(const Shape&s){
  auto shape=cqjolt::make_shape(s);JPH::BodyCreationSettings config(shape,cqjolt::position(s.center),cqjolt::rotation(s.basis),JPH::EMotionType::Kinematic,JPH::ObjectLayer(s.mask));config.mUserData=uint64_t(s.id);
  auto id=system.GetBodyInterface().CreateAndAddBody(config,JPH::EActivation::DontActivate);if(id.IsInvalid())throw std::runtime_error("fixture body capacity exhausted");body_ids.push_back(id);return id;
 }
 bool resize_fixture(size_t i,double height){
  auto&actor=*characters.at(i);auto old=actor.GetShapeOffset();JPH::RefConst<JPH::Shape> hull=new JPH::CylinderShape(float(height*.5),.3f,0);
  actor.SetShapeOffset(JPH::Vec3(0,float(height*.5+.005),0));
  bool clear=actor.SetShape(hull,.001f,{},cqjolt::Layers(3),{}, {},*scratch[0]);
  if(!clear)actor.SetShapeOffset(old);
  return clear;
 }
 Result execute(const Query&q,size_t index,int worker){
  Result result;allocations=0;count_allocations=true;
  if(int(q.shape.kind)==0)result.hit=ray(q.shape.center,q.delta,q.shape.mask,-1,result.stats);
  else if(int(q.shape.kind)==5){
   auto &actor=*characters[index];auto &allocator=*scratch[size_t(worker)];cqjolt::Layers layers(q.shape.mask);cqjolt::Bodies bodies(-1,result.stats);
   actor.SetPosition(cqjolt::position(q.shape.center));actor.SetLinearVelocity(cqjolt::vec(q.delta));
   actor.RefreshContacts({},layers,bodies,{},allocator);
   bool was_grounded=actor.GetGroundState()==JPH::CharacterBase::EGroundState::OnGround;
   V command=q.delta;
   if(options.carry_support&&was_grounded&&command.y<=0)command=command+cqjolt::value(actor.GetGroundVelocity());
   V before=cqjolt::value(actor.GetPosition());
   // Jolt keeps desired velocity separately from its contact solver output.
   // Capture the solver output for the Godot-style post-slide velocity contract.
   cqjolt::MoveListener listener;listener.allow_side_push=options.allow_side_push;listener.resolved=actor.CancelVelocityTowardsSteepSlopes(cqjolt::vec(command));
   actor.SetLinearVelocity(listener.resolved);actor.SetListener(&listener);
   actor.Update(1.f/30,JPH::Vec3::sZero(),{},layers,bodies,{},allocator);
   actor.SetListener(nullptr);
   bool stepped=false;
   if(options.stair_height>0&&was_grounded&&command.y<=0&&actor.CanWalkStairs(cqjolt::vec(command))){
    V horizontal{command.x/30,0,command.z/30},achieved=cqjolt::value(actor.GetPosition())-before;achieved.y=0;
    V remaining=horizontal-achieved;
    if(remaining.dot(horizontal)>1e-8)stepped=actor.WalkStairs(1.f/30,JPH::Vec3(0,float(options.stair_height),0),cqjolt::vec(remaining),cqjolt::vec(horizontal.unit()*std::min(.15,remaining.length())),JPH::Vec3::sZero(),{},layers,bodies,{},allocator);
    if(stepped)listener.resolved=cqjolt::vec(command);
   }
   result.move.stepped=stepped;
   if(q.delta.y<=0&&actor.GetGroundState()!=JPH::CharacterBase::EGroundState::OnGround)actor.StickToFloor(JPH::Vec3(0,-.0625f,0),{},layers,bodies,{},allocator);
   result.move.position=cqjolt::value(actor.GetPosition());result.move.velocity=cqjolt::value(listener.resolved);
   result.move.grounded=actor.GetGroundState()==JPH::CharacterBase::EGroundState::OnGround;
   if(result.move.grounded&&q.delta.y<=0)result.move.velocity.y=0;
   result.move.support=actor.GetGroundBodyID().IsInvalid()?-1:int(system.GetBodyInterface().GetUserData(actor.GetGroundBodyID()));
   actor.SetLinearVelocity(cqjolt::vec(result.move.velocity));
   result.move.contacts=int(actor.GetActiveContacts().size());result.move.converged=!actor.GetMaxHitsExceeded();
   if(!result.move.converged){result.stats.unresolved++;result.move.position=q.shape.center;result.move.velocity={};result.move.grounded=false;}
  }else result.hit=sweep(query_shapes[index],q.shape,q.delta,options.sweep_margin,q.shape.mask,-1,result.stats);
  count_allocations=false;result.allocations=allocations;return result;
 }
};

// Candidate dynamic solution: relative translation before ordered pair commit.
// Rotating compounds and arbitrary coupled islands are deliberately not solved.
#include <Jolt/Physics/Collision/CollisionDispatch.h>
inline Hit jolt_relative_sweep(const Shape&a,const Shape&b,V a_motion,V b_motion){
 auto as=cqjolt::make_shape(a),bs=cqjolt::make_shape(b);JPH::ShapeCast cast(as,JPH::Vec3::sOne(),JPH::Mat44::sRotationTranslation(cqjolt::rotation(a.basis),cqjolt::vec(a.center-b.center)),cqjolt::vec(a_motion-b_motion));
 JPH::ShapeCastSettings settings;settings.mReturnDeepestPoint=true;settings.mCollisionTolerance=1e-5f;
 JPH::ClosestHitCollisionCollector<JPH::CastShapeCollector> hits;
 JPH::CollisionDispatch::sCastShapeVsShapeWorldSpace(cast,settings,bs,JPH::Vec3::sOne(),{},JPH::Mat44::sRotationTranslation(cqjolt::rotation(b.basis),JPH::Vec3::sZero()),{},{},hits);
 Hit out;if(hits.HadHit()){out.hit=true;out.fraction=hits.mHit.mFraction;out.id=b.id;out.normal=-cqjolt::value(hits.mHit.mPenetrationAxis.NormalizedOr(JPH::Vec3::sAxisY()));out.point=b.center+b_motion*out.fraction+cqjolt::value(hits.mHit.mContactPointOn2);}return out;
}
