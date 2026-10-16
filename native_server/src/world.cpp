#include "world.h"
#include <Jolt/Jolt.h>
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Core/JobSystemThreadPool.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/Character/CharacterVirtual.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/CylinderShape.h>
#include <Jolt/Physics/Collision/Shape/CapsuleShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/Collision/Shape/HeightFieldShape.h>
#include <Jolt/Physics/Collision/Shape/MeshShape.h>
#include <Jolt/Physics/Collision/Shape/ConvexHullShape.h>
#include <Jolt/Physics/Collision/Shape/ScaledShape.h>
#include <Jolt/Physics/Collision/Shape/RotatedTranslatedShape.h>
#include <Jolt/Physics/Collision/Shape/StaticCompoundShape.h>
#include <Jolt/Physics/Collision/RayCast.h>
#include <Jolt/Physics/Collision/ShapeCast.h>
#include <Jolt/Physics/Collision/CastResult.h>
#include <Jolt/Physics/Collision/CollisionCollectorImpl.h>
#include <unordered_set>
#include <thread>
#include <iostream>
namespace cqserver {
namespace {
JPH::Vec3 jv(V v){return {float(v.x),float(v.y),float(v.z)};}
V cv(JPH::Vec3Arg v){return {v.GetX(),v.GetY(),v.GetZ()};}
constexpr JPH::ObjectLayer STATIC=0,PLAYER=1,VEHICLE=2,TURRET=3,DISABLED=4;
struct Layers final:JPH::BroadPhaseLayerInterface {
 JPH::uint GetNumBroadPhaseLayers()const override{return 2;}
 JPH::BroadPhaseLayer GetBroadPhaseLayer(JPH::ObjectLayer layer)const override{return JPH::BroadPhaseLayer(layer==STATIC?0:1);}
#if defined(JPH_EXTERNAL_PROFILE) || defined(JPH_PROFILE_ENABLED)
 const char*GetBroadPhaseLayerName(JPH::BroadPhaseLayer layer)const override{return layer.GetValue()==0?"STATIC":"MOVING";}
#endif
};
struct BroadFilter final:JPH::ObjectVsBroadPhaseLayerFilter{bool ShouldCollide(JPH::ObjectLayer a,JPH::BroadPhaseLayer b)const override{return a!=DISABLED&&(a!=STATIC||b.GetValue()!=0);}};
struct Pairs final:JPH::ObjectLayerPairFilter{bool ShouldCollide(JPH::ObjectLayer a,JPH::ObjectLayer b)const override{return a!=DISABLED&&b!=DISABLED&&(a!=STATIC||b!=STATIC)&&!((a==PLAYER&&b==VEHICLE)||(a==VEHICLE&&b==PLAYER));}};
struct ObjectFilter final:JPH::ObjectLayerFilter{bool actors=false;explicit ObjectFilter(bool include=false):actors(include){}bool ShouldCollide(JPH::ObjectLayer layer)const override{return layer!=DISABLED&&(actors||layer!=PLAYER);}};
struct MotorFilter final:JPH::ObjectLayerFilter{bool vehicle;explicit MotorFilter(bool v=false):vehicle(v){}bool ShouldCollide(JPH::ObjectLayer layer)const override{return layer!=DISABLED&&(!vehicle||layer!=PLAYER);}};
struct Ignore final:JPH::BodyFilter {JPH::BodyID a,b;Ignore(JPH::BodyID aa={},JPH::BodyID bb={}):a(aa),b(bb){}bool ShouldCollide(const JPH::BodyID&id)const override{return id!=a&&id!=b;}};
void initialize(){static const bool ready=[](){JPH::RegisterDefaultAllocator();JPH::Factory::sInstance=new JPH::Factory();JPH::RegisterTypes();return true;}();(void)ready;}
JPH::RefConst<JPH::Shape> checked(const JPH::ShapeSettings::ShapeResult &r){if(r.HasError())throw std::runtime_error(std::string("Jolt shape: ")+r.GetError().c_str());return r.Get();}
JPH::RefConst<JPH::Shape> hull(double height){JPH::RefConst<JPH::Shape> cylinder=new JPH::CylinderShape(float(height*.5),.3f,.01f);return new JPH::RotatedTranslatedShape(JPH::Vec3(0,float(height*.5+.005),0),JPH::Quat::sIdentity(),cylinder);}
}
struct World::Impl {
 const WorldData&data;
 Layers layers;BroadFilter broad;Pairs pairs;
 JPH::PhysicsSystem physics;
 JPH::TempAllocatorImplWithMallocFallback temp{32*1024*1024};
 JPH::JobSystemThreadPool jobs{JPH::cMaxPhysicsJobs,JPH::cMaxPhysicsBarriers,2};
 struct Motor{JPH::Ref<JPH::CharacterVirtual>character;double height=1.65;bool disabled=false;};
 std::unordered_map<int64_t,Motor>actors;
 std::unordered_map<uint64_t,Motor>vehicles;
 std::unordered_map<uint64_t,JPH::BodyID>entities;
 std::unordered_map<uint32_t,std::pair<uint64_t,uint8_t>>entity_ids;
 std::vector<JPH::BodyID>bodies;
 std::unordered_set<uint32_t>disabled;
 std::vector<JPH::BodyID>extra;
 std::unordered_map<int,std::vector<JPH::BodyID>>wall_bodies;
 std::unordered_map<uint64_t,JPH::BodyID>turrets;
 explicit Impl(const WorldData&d):data(d){physics.Init(65536,0,16384,8192,layers,broad,pairs);physics.SetGravity(JPH::Vec3(0,-20,0));}
 JPH::RefConst<JPH::Shape> shape(const Json&r){auto type=r.at("type").get<std::string>();
  if(type=="BoxShape3D")return new JPH::BoxShape(jv(vec(r.at("size"))*.5),.005f);
  if(type=="CylinderShape3D")return new JPH::CylinderShape(float(r.at("height").get<double>()*.5),r.at("radius").get<float>(),.005f);
  if(type=="CapsuleShape3D")return new JPH::CapsuleShape(float(std::max(0.,r.at("height").get<double>()*.5-r.at("radius").get<double>())),r.at("radius").get<float>());
  if(type=="SphereShape3D")return new JPH::SphereShape(r.at("radius").get<float>());
  auto values=data.floats(r.at("data"));
  if(type=="HeightMapShape3D"){uint32_t size=r.at("width");if(size!=r.at("depth").get<uint32_t>()||uint64_t(size)*size!=values.size())throw std::runtime_error("Invalid square heightfield");JPH::HeightFieldShapeSettings settings(values.data(),JPH::Vec3(-float(size-1)*.5f,0,-float(size-1)*.5f),JPH::Vec3::sReplicate(1),size);return checked(settings.Create());}
  if(values.size()%3)throw std::runtime_error("Invalid shape vertices");
  if(type=="ConcavePolygonShape3D"){if(values.size()%9)throw std::runtime_error("Invalid collision triangles");JPH::TriangleList triangles;for(size_t i=0;i<values.size();i+=9)triangles.emplace_back(JPH::Float3(values[i],values[i+1],values[i+2]),JPH::Float3(values[i+6],values[i+7],values[i+8]),JPH::Float3(values[i+3],values[i+4],values[i+5]));JPH::MeshShapeSettings settings(triangles);return checked(settings.Create());}
  if(type=="ConvexPolygonShape3D"){JPH::Array<JPH::Vec3>points;for(size_t i=0;i<values.size();i+=3)points.emplace_back(values[i],values[i+1],values[i+2]);JPH::ConvexHullShapeSettings settings(points);settings.mMaxConvexRadius=.005f;return checked(settings.Create());}
  throw std::runtime_error("Unsupported collision shape "+type);
 }
 Motor motor(JPH::RefConst<JPH::Shape>shape,V position,JPH::ObjectLayer layer,double slope=std::acos(.7)*180/3.141592653589793){
  JPH::CharacterVirtualSettings settings;settings.mShape=shape;settings.mInnerBodyShape=shape;settings.mInnerBodyLayer=layer;settings.mCharacterPadding=.001f;settings.mPredictiveContactDistance=.02f;settings.mMaxCollisionIterations=8;settings.mMaxSlopeAngle=JPH::DegreesToRadians(float(slope));settings.mSupportingVolume=JPH::Plane(JPH::Vec3::sAxisY(),-.35f);settings.mMaxStrength=0;
  Motor m;m.character=new JPH::CharacterVirtual(&settings,jv(position),JPH::Quat::sIdentity(),0,&physics);return m;
 }
 JPH::BodyID actor(int64_t id)const{auto it=actors.find(id);return it==actors.end()?JPH::BodyID():it->second.character->GetInnerBodyID();}
 JPH::BodyID entity(uint64_t id)const{auto it=entities.find(id);return it==entities.end()?JPH::BodyID():it->second;}
 void enabled(JPH::BodyID body,bool yes){uint32_t id=body.GetIndexAndSequenceNumber();if(yes){if(disabled.erase(id))physics.GetBodyInterface().AddBody(body,JPH::EActivation::DontActivate);}else if(disabled.insert(id).second)physics.GetBodyInterface().RemoveBody(body);}
 cqauthority::Hit cast(V from,V to,double radius,cqauthority::Handle ignore,uint64_t excluded,bool include_actors=false){
  cqauthority::Hit out;JPH::BodyID hit_body;JPH::SubShapeID sub;float fraction=1;JPH::Vec3 normal;
  ObjectFilter objects(include_actors);Ignore filter(actor(ignore.id),entity(excluded));
  if(radius<=0){JPH::RRayCast ray(jv(from),jv(to-from));JPH::RayCastResult hit;if(!physics.GetNarrowPhaseQuery().CastRay(ray,hit,{},objects,filter))return out;fraction=hit.mFraction;hit_body=hit.mBodyID;sub=hit.mSubShapeID2;normal=physics.GetBodyInterface().GetTransformedShape(hit_body).GetWorldSpaceSurfaceNormal(sub,ray.GetPointOnRay(fraction));}
  else{JPH::RefConst<JPH::Shape>sphere=new JPH::SphereShape(float(std::max(radius,.0001)));JPH::RShapeCast shape(sphere,JPH::Vec3::sReplicate(1),JPH::RMat44::sTranslation(jv(from)),jv(to-from));JPH::ShapeCastSettings settings;settings.mReturnDeepestPoint=true;settings.mBackFaceModeTriangles=JPH::EBackFaceMode::CollideWithBackFaces;JPH::ClosestHitCollisionCollector<JPH::CastShapeCollector>collector;physics.GetNarrowPhaseQuery().CastShape(shape,settings,jv(from),collector,{},objects,filter);if(!collector.HadHit())return out;fraction=collector.mHit.mFraction;hit_body=collector.mHit.mBodyID2;normal=-collector.mHit.mPenetrationAxis.NormalizedOr(JPH::Vec3::sAxisY());}
  out.blocked=true;out.fraction=fraction;out.position=from+(to-from)*fraction;out.normal=cv(normal);auto entity=entity_ids.find(hit_body.GetIndexAndSequenceNumber());if(entity!=entity_ids.end()){out.entity=entity->second.first;out.entity_kind=entity->second.second;}
  if(include_actors)for(auto&entry:actors)if(entry.second.character->GetInnerBodyID()==hit_body)out.actor={entry.first,0};return out;
 }
};
World::World(const WorldData&d,cqauthority::Core&core):core_(core),surface(d.metadata.at("world_terrain")),navigation(d.directory/"navigation.bin",d.metadata.at("nav_links"),d.metadata.at("roads")){
 initialize();p_=std::make_unique<Impl>(d);std::vector<JPH::RefConst<JPH::Shape>>shapes;for(const auto&r:d.metadata.at("shapes"))shapes.push_back(p_->shape(r));
 for(const auto&row:d.metadata.at("bodies")){JPH::StaticCompoundShapeSettings compound;
  for(const auto&piece:row.at("pieces")){auto index=piece.at("shape").get<size_t>();if(index>=shapes.size())throw std::runtime_error("Collision shape index");const auto&t=piece.at("transform");V x=vec(t.at(0)),y=vec(t.at(1)),z=vec(t.at(2)),at=vec(t.at(3));V scale{x.length(),y.length(),z.length()};if(std::min({scale.x,scale.y,scale.z})<=0)throw std::runtime_error("Invalid collision scale");JPH::Mat44 frame(JPH::Vec4(jv(x/scale.x),0),JPH::Vec4(jv(y/scale.y),0),JPH::Vec4(jv(z/scale.z),0),JPH::Vec3::sZero());JPH::Quat rotation=frame.GetQuaternion().Normalized();JPH::RefConst<JPH::Shape>shape=shapes[index];if((scale-V{1,1,1}).length()>.00001)shape=checked(JPH::ScaledShapeSettings(shape,jv(scale)).Create());compound.AddShape(jv(at),rotation,shape);}
  auto shape=checked(compound.Create());JPH::BodyCreationSettings settings(shape,JPH::RVec3::sZero(),JPH::Quat::sIdentity(),JPH::EMotionType::Static,STATIC);auto body=p_->physics.GetBodyInterface().CreateAndAddBody(settings,JPH::EActivation::DontActivate);if(body.IsInvalid())throw std::runtime_error("Jolt body capacity");p_->bodies.push_back(body);int wall=row.value("wall",-1);if(wall>=0)p_->wall_bodies[wall].push_back(body);
 }
 p_->physics.OptimizeBroadPhase();
 for(const auto&v:d.metadata.at("vehicles")){int index=core_.add_vehicle(cqauthority::VehicleKind(v.at("kind").get<int>()),vec(v.at("position")),v.at("yaw"),v.at("team"));if(index<0)throw std::runtime_error("Vehicle configuration rejected");sync_vehicle(core_.vehicles()[index]);}
}
World::~World(){if(!p_)return;for(auto&entry:p_->actors)p_->enabled(entry.second.character->GetInnerBodyID(),true);for(auto&entry:p_->vehicles)p_->enabled(entry.second.character->GetInnerBodyID(),true);p_->actors.clear();p_->vehicles.clear();for(auto&entry:p_->turrets){p_->enabled(entry.second,false);p_->physics.GetBodyInterface().DestroyBody(entry.second);}for(auto b:p_->bodies){p_->enabled(b,false);p_->physics.GetBodyInterface().DestroyBody(b);}for(auto b:p_->extra){p_->enabled(b,false);p_->physics.GetBodyInterface().DestroyBody(b);}}
const WorldData&World::data()const{return p_->data;}
void World::add_actor(cqauthority::Handle h,V position){auto m=p_->motor(hull(1.65),position,PLAYER);p_->actors[h.id]=std::move(m);}
void World::remove_actor(int64_t id){auto it=p_->actors.find(id);if(it==p_->actors.end())return;p_->enabled(it->second.character->GetInnerBodyID(),true);p_->actors.erase(it);}
void World::set_body(size_t i,bool enabled){if(i>=p_->bodies.size())throw std::runtime_error("Collision body index");p_->enabled(p_->bodies[i],enabled);}
bool World::body_active(size_t i)const{return i<p_->bodies.size()&&!p_->disabled.count(p_->bodies[i].GetIndexAndSequenceNumber());}
bool World::wall_visible(V a,V b,int wall)const{
 struct Filter: JPH::BodyFilter{std::unordered_set<uint32_t>skip;bool ShouldCollide(const JPH::BodyID&id)const override{return !skip.count(id.GetIndexAndSequenceNumber());}}filter;
 auto found=p_->wall_bodies.find(wall);if(found!=p_->wall_bodies.end())for(auto body:found->second)filter.skip.insert(body.GetIndexAndSequenceNumber());
 ObjectFilter objects;JPH::RayCastResult hit;bool blocked=p_->physics.GetNarrowPhaseQuery().CastRay(JPH::RRayCast(jv(a),jv(b-a)),hit,{},objects,filter);return !blocked||hit.mFraction>.98f;
}
std::vector<uint32_t>World::add_boxes(const Json&rows,bool enabled,int wall){std::vector<uint32_t>out;for(const auto&r:rows){auto shape=JPH::RefConst<JPH::Shape>(new JPH::BoxShape(jv(vec(r.at("size"))*.5),.005f));JPH::BodyCreationSettings settings(shape,jv(vec(r.at("center"))),JPH::Quat::sIdentity(),JPH::EMotionType::Static,STATIC);JPH::BodyID id=p_->physics.GetBodyInterface().CreateAndAddBody(settings,JPH::EActivation::DontActivate);if(id.IsInvalid())throw std::runtime_error("Rubble collision capacity");out.push_back(uint32_t(p_->extra.size()));p_->extra.push_back(id);if(wall>=0)p_->wall_bodies[wall].push_back(id);if(!enabled)p_->enabled(id,false);}return out;}
void World::set_extra_body(uint32_t i,bool enabled){if(i>=p_->extra.size())throw std::runtime_error("Extra body index");p_->enabled(p_->extra[i],enabled);}
bool World::edge(const cqauthority::Motion&m){V offset=V{m.velocity.x,0,m.velocity.z}.unit()*.5;auto it=p_->actors.find(m.actor.id);double rise=0;if(it!=p_->actors.end()&&it->second.character->IsSupported()){V n=cv(it->second.character->GetGroundNormal());if(n.y>.7)rise=std::max(0.,-n.dot(offset)/n.y);}V from=m.position+offset+V{0,rise+.02,0};return !p_->cast(from,from-V{0,34./32,0},0,m.actor,0,true).blocked;}
double World::posture(cqauthority::Handle h,double requested){auto it=p_->actors.find(h.id);if(it==p_->actors.end())return requested;auto&m=it->second;if(std::abs(m.height-requested)<.00001)return requested;auto shape=hull(requested);MotorFilter objects;Ignore filter(m.character->GetInnerBodyID());bool allowed=m.character->SetShape(shape,.005f,{},objects,filter,{},p_->temp);if(allowed){m.character->SetInnerBodyShape(shape);m.height=requested;}return m.height;}
cqauthority::Moved World::move(const cqauthority::Motion&m,double dt){auto it=p_->actors.find(m.actor.id);if(it==p_->actors.end())return {m.position,{},m.height,false,false};auto&motor=it->second;auto*player=core_.resolve(m.actor);MotorFilter objects(player&&player->incapacitated);Ignore filter(motor.character->GetInnerBodyID());motor.character->SetPosition(jv(m.position));motor.character->SetRotation(JPH::Quat::sRotation(JPH::Vec3::sAxisY(),float(m.yaw)));motor.character->SetLinearVelocity(jv(m.velocity));JPH::CharacterVirtual::ExtendedUpdateSettings step;step.mWalkStairsStepUp=JPH::Vec3(0,m.step&&m.grounded&&m.velocity.y<=0?float(m.height<.8?.20:.55):0,0);step.mStickToFloorStepDown=JPH::Vec3(0,m.step?-.0625f:0,0);motor.character->ExtendedUpdate(float(dt),JPH::Vec3(0,-20,0),step,{},objects,filter,{},p_->temp);if(player&&player->incapacitated)p_->enabled(motor.character->GetInnerBodyID(),false);V velocity=cv(motor.character->GetLinearVelocity());bool ceiling=m.velocity.y>0&&velocity.y<m.velocity.y*.1;return {cv(motor.character->GetPosition()),velocity,m.height,motor.character->GetGroundState()==JPH::CharacterBase::EGroundState::OnGround,ceiling};}
cqauthority::Hit World::trace(V a,V b,cqauthority::Handle h){return p_->cast(a,b,0,h,0,true);}
cqauthority::Hit World::world_trace(V a,V b,cqauthority::Handle h){return p_->cast(a,b,0,h,0);}
cqauthority::Hit World::sweep_world(V a,V b,double radius,cqauthority::Handle h,uint64_t excluded){return p_->cast(a,b,radius,h,excluded);}
double World::world_fraction(V a,V b,double radius,cqauthority::Handle h){auto hit=sweep_world(a,b,radius,h,0);return hit.blocked?hit.fraction:cqauthority::infinity;}
cqauthority::Hit World::entity_ray(V a,V b,uint64_t excluded){return p_->cast(a,b,0,{},excluded);}
double World::ground_height(double x,double z){auto hit=entity_ray({x,2048,z},{x,-512,z},0);return hit.blocked?hit.position.y:0;}
bool World::clear_exit(cqauthority::Handle h,V at,uint64_t excluded){auto hit=p_->cast(at+V{0,.31,0},at+V{0,1.34,0},.29,h,excluded,true);return !hit.blocked;}
void World::seat(cqauthority::Handle h,V at,bool mounted){auto it=p_->actors.find(h.id);if(it==p_->actors.end())return;it->second.character->SetPosition(jv(at));it->second.disabled=mounted;p_->enabled(it->second.character->GetInnerBodyID(),!mounted);}
void World::teleport(cqauthority::Handle h,V at){auto it=p_->actors.find(h.id);if(it==p_->actors.end())return;it->second.character->SetPosition(jv(at));it->second.character->SetLinearVelocity(JPH::Vec3::sZero());it->second.disabled=false;p_->enabled(it->second.character->GetInnerBodyID(),true);posture(h,1.65);}
void World::sync_vehicle(const cqauthority::Vehicle&v){auto it=p_->vehicles.find(v.key);if(it==p_->vehicles.end()){V size=cqauthority::vehicle_profile(v.kind).size;JPH::RefConst<JPH::Shape>box=new JPH::BoxShape(jv(size*.5),.02f);JPH::RefConst<JPH::Shape>shape=new JPH::RotatedTranslatedShape(JPH::Vec3(0,float(size.y*.5+.02),0),JPH::Quat::sIdentity(),box);auto m=p_->motor(shape,v.position,VEHICLE,30);auto id=m.character->GetInnerBodyID();p_->entities[v.key]=id;p_->entity_ids[id.GetIndexAndSequenceNumber()]={v.key,1};it=p_->vehicles.emplace(v.key,std::move(m)).first;}it->second.character->SetPosition(jv(v.position));it->second.character->SetRotation(JPH::Quat::sRotation(JPH::Vec3::sAxisY(),float(v.yaw)));p_->enabled(it->second.character->GetInnerBodyID(),v.hp>0);}
cqauthority::VehicleMoved World::move_vehicle(const cqauthority::Vehicle&v,V velocity,double dt){sync_vehicle(v);auto&m=p_->vehicles.at(v.key);MotorFilter objects(true);Ignore filter(m.character->GetInnerBodyID());m.character->SetLinearVelocity(jv(velocity));JPH::CharacterVirtual::ExtendedUpdateSettings step;step.mWalkStairsStepUp=JPH::Vec3::sZero();step.mStickToFloorStepDown=JPH::Vec3(0,-.45f,0);m.character->ExtendedUpdate(float(dt),JPH::Vec3(0,-20,0),step,{},objects,filter,{},p_->temp);bool ground=m.character->GetGroundState()==JPH::CharacterBase::EGroundState::OnGround;V n=ground?cv(m.character->GetGroundNormal()):V{0,1,0};V at=cv(m.character->GetPosition());return {at,cv(m.character->GetLinearVelocity()),n,at.y+(v.kind==cqauthority::VehicleKind::LIGHT||v.kind==cqauthority::VehicleKind::HEAVY?.25:0),ground,ground&&n.y>=std::cos(30*3.141592653589793/180)};}
V World::room_move(cqauthority::Handle h,V local,double yaw){auto*player=core_.resolve(h);auto it=p_->actors.find(h.id);if(!player||it==p_->actors.end())return {};V shift=cqauthority::B::yaw(yaw).apply(local);if(shift.length()<.000001)return {};JPH::RShapeCast shape(it->second.character->GetShape(),JPH::Vec3::sReplicate(1),JPH::RMat44::sTranslation(jv(player->position)),jv(shift));JPH::ShapeCastSettings settings;settings.mReturnDeepestPoint=true;JPH::ClosestHitCollisionCollector<JPH::CastShapeCollector>collector;ObjectFilter objects(true);Ignore filter(it->second.character->GetInnerBodyID());p_->physics.GetNarrowPhaseQuery().CastShape(shape,settings,jv(player->position),collector,{},objects,filter);double fraction=collector.HadHit()?std::max(0.,double(collector.mHit.mFraction)-.001):1.;return shift*fraction;}

void World::sync(double dt){
 for(const auto&player:core_.players())if(player.active){auto it=p_->actors.find(player.handle.id);if(it!=p_->actors.end())p_->enabled(it->second.character->GetInnerBodyID(),!player.dead&&!player.staging&&!player.incapacitated&&player.vehicle<0);}
 std::unordered_set<uint64_t>alive;
 for(const auto&t:core_.turrets())if(t.active&&t.hp>0){alive.insert(t.key);if(!p_->turrets.count(t.key)){JPH::RefConst<JPH::Shape>shape=new JPH::BoxShape(JPH::Vec3(.6f,.8f,.6f),.01f);JPH::BodyCreationSettings s(shape,jv(t.position+V{0,.8,0}),JPH::Quat::sIdentity(),JPH::EMotionType::Static,TURRET);auto id=p_->physics.GetBodyInterface().CreateAndAddBody(s,JPH::EActivation::DontActivate);p_->turrets[t.key]=id;p_->entities[t.key]=id;p_->entity_ids[id.GetIndexAndSequenceNumber()]={t.key,2};}}
 for(auto it=p_->turrets.begin();it!=p_->turrets.end();)if(!alive.count(it->first)){p_->enabled(it->second,false);p_->physics.GetBodyInterface().DestroyBody(it->second);p_->disabled.erase(it->second.GetIndexAndSequenceNumber());p_->entity_ids.erase(it->second.GetIndexAndSequenceNumber());p_->entities.erase(it->first);it=p_->turrets.erase(it);}else ++it;
 p_->physics.Update(float(dt),1,&p_->temp,&p_->jobs);
}
}
