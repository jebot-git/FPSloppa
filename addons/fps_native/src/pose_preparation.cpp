#include "poses.h"
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;
// Match GDScript transform/vector expressions while retaining multiplication order.
namespace godot {
static Vector3 operator*(const Basis &b,const Vector3 &v){return b.xform(v);}
static Vector3 operator*(const Transform3D &t,const Vector3 &v){return t.xform(v);}
}

// One synchronous solve boundary: reuse the solver caches and read live tracking
// each time. Cadence, interpolation and death transitions remain in pose.gd.
void FPSPose::prepare_live(Skeleton3D *sk,Node3D *rig,Dictionary ids,const Dictionary &rest,Dictionary rotations,Dictionary floor_heights,bool sample_floor) {
 if(!sk||!rig)return;
 const Vector3 up(0,1,0),right(1,0,0),forward(0,0,-1);
 const double pi=3.14159265358979323846;
 const bool optimized=rig->get("animation_optimized"),grounded=rig->get("grounded"),first_person=rig->get("first_person");
 const Dictionary xr=rig->get("xr_pose"),body=xr.get("body",Dictionary());
 Object *gait=rig->get("gait");
 const double prone=gait->get("prone_blend"),assist=gait->get("assist_weight"),collider=rig->get("collider_height"),neutral_hip=rig->get("neutral_hip_height"),pitch=rig->get("aim_pitch");
 const Dictionary offsets=gait->get("offsets"),foot_heights=rig->get("neutral_foot_heights");
 const Transform3D tracking=rig->call("tracking_transform");
 const Basis rig_basis=rig->get_global_basis(),sk_basis=sk->get_global_basis(),sk_inverse=sk_basis.inverse(),sk_ortho_inverse=sk_basis.orthonormalized().inverse();
 const Basis reference_frame=tracking.basis.orthonormalized().inverse()*sk_basis.orthonormalized();
 auto bone=[&](const String &name)->int{if(!ids.has(name))ids[name]=sk->find_bone(name);return ids[name];};
 auto rotation=[&](int index)->Quaternion{if(!optimized)return sk->get_bone_rest(index).basis.get_rotation_quaternion();if(!rotations.has(index))rotations[index]=sk->get_bone_rest(index).basis.get_rotation_quaternion();return rotations[index];};
 auto reference=[&](int index)->Basis{return index<0||index>=sk->get_bone_count()?Basis():reference_frame*sk->get_bone_global_rest(index).basis.orthonormalized();};
 auto chain=[&](const String &side,const String &limb,const String &tip,Vector3 target,Vector3 pole){solve(sk,bone(side+String("Upper")+limb),bone(side+String("Lower")+limb),bone(side+tip),target,pole);};
 for(const char *name:{"Hips","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftHand","RightHand","Head","Chest"}){
  int index=bone(name);if(index>=0)sk->set_bone_pose_rotation(index,rotation(index));
 }
 const int hips=bone("Hips");Vector3 offset;
 if(!xr.is_empty()){
  Transform3D head=xr["head"];offset=rig_basis.inverse()*tracking.basis*(head.origin-Vector3(0,1.65,0));
  offset=Vector3(offset.x*.45,std::clamp(double(offset.y),-.90,.1),offset.z*.45);
 }else offset.y=collider-1.65;
 if(prone>0)offset=offset.lerp(Vector3(0,.30-neutral_hip,.35),prone);
 if(!body.has("hips")){
  offset.y+=double(gait->get("bob"))-double(gait->get("landing"))*.5;
  sk->set_bone_pose_position(hips,sk->get_bone_rest(hips).origin+sk_inverse*rig_basis*offset);
  if(prone>0)orient(sk,hips,rig_basis*Basis(right,-pi*.43*prone)*reference(hips));
 }else{
  Transform3D fitted=body["hips"];fitted.origin.y+=neutral_hip-.92;Transform3D target=tracking*fitted;
  int parent=sk->get_bone_parent(hips);Vector3 local=sk->to_local(target.origin);
  if(parent>=0)local=sk->get_bone_global_pose(parent).affine_inverse()*local;
  sk->set_bone_pose_position(hips,local);orient(sk,hips,target.basis*reference(hips));
 }
 if(body.has("chest")){int chest=bone("Chest");orient(sk,chest,tracking.basis*Transform3D(body["chest"]).basis*reference(chest));}
 // Limb targets retain the authored rest axes, floor cadence and tracker priority.
 for(int side_index=0;side_index<2;++side_index){
  const String side=side_index==0?"Left":"Right",key=side_index==0?"left":"right";const double sign=side_index==0?-1.:1.;
  int foot_index=bone(side+String("Foot"));if(foot_index<0||bone(side+String("UpperLeg"))<0)continue;
  Transform3D foot_rest=rest[foot_index];Vector3 neutral=rig->to_local(sk->to_global(foot_rest.origin));
  Vector3 gait_offset=offsets[key],foot=Vector3(sign*.13,neutral.y,neutral.z)+gait_offset;
  if(int(rig->get("preview_mode"))<0&&rig->is_inside_tree()&&sample_floor&&grounded&&(!optimized||!body.has(key+String("_foot")))){
   Vector3 world=rig->to_global(foot);
   Ref<PhysicsRayQueryParameters3D> query=PhysicsRayQueryParameters3D::create(world+up*.4,world-up*.5,1);
   Dictionary hit=rig->get_world_3d()->get_direct_space_state()->intersect_ray(query);
   floor_heights[side]=hit.is_empty()?double(neutral.y):double(rig->to_local(hit["position"]).y)+double(neutral.y);
  }
  if(grounded&&floor_heights.has(side))foot.y=std::max(double(foot.y),double(floor_heights[side]));
  Vector3 foot_world=rig->to_global(foot),hip_world=sk->to_global(sk->get_bone_global_pose(bone(side+String("UpperLeg"))).origin);
  Vector3 knee_world=hip_world+rig_basis*Vector3(sign*.08,0,-.65);
  if(body.has(key+String("_foot"))){
   Transform3D fitted=body[key+String("_foot")];fitted.origin.y+=double(foot_heights.get(key,.08))-.08;
   foot_world=(tracking*fitted).origin;foot_world+=rig_basis*gait_offset*assist*.6;
  }else if(prone>.5)knee_world=hip_world+rig_basis*Vector3(sign*.25,-.3,.45);
  if(body.has("hips")&&!body.has(key+String("_knee"))){
   Basis pelvis=tracking.basis*Transform3D(body["hips"]).basis;Vector3 direction=-pelvis.get_column(2);direction.y=0;
   if(direction.length()<.1){direction=-tracking.basis.get_column(2);direction.y=0;}direction=direction.normalized();
   if(body.has(key+String("_foot"))){
    Vector3 toe=-(tracking.basis*Transform3D(body[key+String("_foot")]).basis).get_column(2);toe.y=0;
    if(toe.length()>.1){double angle=direction.signed_angle_to(toe.normalized(),up);direction=direction.rotated(up,std::clamp(angle,-pi/6,pi/6)*.5);}
   }
   knee_world=hip_world+direction*.65+direction.cross(up)*(side_index==0?-.06:.06);
  }
  if(body.has(key+String("_knee"))){knee_world=(tracking*Transform3D(body[key+String("_knee")])).origin;knee_world+=rig_basis*gait_offset*assist*.5;}
  chain(side,"Leg","Foot",foot_world,knee_world);
  int foot_parent=sk->get_bone_parent(foot_index);
  sk->set_bone_pose_rotation(foot_index,((foot_parent>=0?sk->get_bone_global_pose(foot_parent).basis.inverse():Basis())*foot_rest.basis).get_rotation_quaternion());
  if(body.has(key+String("_foot")))orient(sk,foot_index,tracking.basis*Transform3D(body[key+String("_foot")]).basis*reference(foot_index));
  int hand=bone(side+String("Hand"));if(hand<0)continue;
  // Keep authored reach when tracking or a prop target lies beyond the arm.
  sk->set_bone_pose_position(hand,sk->get_bone_rest(hand).origin);
  if(!xr.is_empty()){
   Dictionary snaps=xr.get("snapped_hands",Dictionary());bool snapped=snaps.has(key),optical=!snapped&&body.has(key+String("_hand"));
   Transform3D target=tracking*Transform3D(snaps.get(key,xr[key]));
   if(optical)target=tracking*Transform3D(body[key+String("_hand")]);else target.origin+=target.basis.get_column(1)*.06;
   Vector3 elbow=rig->to_global(Vector3(sign*.65,.85,.05));if(body.has(key+String("_elbow")))elbow=(tracking*Transform3D(body[key+String("_elbow")])).origin;
   chain(side,"Arm","Hand",target.origin,elbow);
   int parent=sk->get_bone_parent(hand);
   Basis palm=optical?target.basis:target.basis*Basis(Vector3(0,0,-sign),Vector3(0,-1,0),Vector3(-sign,0,0));
   Basis desired=sk_ortho_inverse*palm;
   sk->set_bone_pose_rotation(hand,((parent>=0?sk->get_bone_global_pose(parent).basis.orthonormalized().inverse():Basis())*desired).get_rotation_quaternion());
  }else{
   bool dual=int(rig->get("weapon_id"))==2;double recoil=rig->get(side_index==0&&dual?"offhand_recoil":"recoil");
   Vector3 grip(side_index==0?.10:.13,1.15,side_index==0?-.46:-.30);if(side_index==0&&dual)grip=Vector3(-.13,1.15,-.30);
   const Vector3 pivot(0,1.3,0);grip=pivot+Basis(right,pitch)*(grip-pivot)+Vector3(0,0,recoil*.035);grip.y-=1.65-collider;
   chain(side,"Arm","Hand",rig->to_global(grip),rig->to_global(Vector3(sign*.65,.8-(1.65-collider)*.65,-.1)));
   int middle=bone(side+String("MiddleProximal"));if(middle>=0){Vector3 direction=sk->get_bone_global_pose(middle).origin-sk->get_bone_global_pose(hand).origin;rotate_toward(sk,hand,direction,sk_inverse*rig_basis*Basis(right,pitch)*forward);}
  }
  // Finger rotations share the same cached rest data as the reference solver.
  PackedFloat32Array curls=body.get(key+String("_curls"),PackedFloat32Array());int finger=0;
  for(const char *digit:{"Thumb","Index","Middle","Ring","Little"}){
   double curl=curls.size()==5?double(curls[finger])*1.25:.8;++finger;
   for(const char *joint:{"Proximal","Intermediate","Distal"}){int index=bone(side+String(digit)+String(joint));if(index>=0)sk->set_bone_pose_rotation(index,rotation(index)*Quaternion(right,curl));}
  }
 }
 int head=bone("Head");
 if(head>=0){
  Quaternion q=rotation(head);
  if(xr.is_empty()){if(prone>.01)orient(sk,head,rig_basis*Basis(right,pitch*.55)*reference(head));else sk->set_bone_pose_rotation(head,q*Quaternion(right,pitch*.55));}
  else{Basis target=tracking.basis*Transform3D(xr["head"]).basis*Basis(up,pi);int parent=sk->get_bone_parent(head);sk->set_bone_pose_rotation(head,((parent>=0?sk->get_bone_global_pose(parent).basis.orthonormalized().inverse():Basis())*sk_ortho_inverse*target).get_rotation_quaternion());}
 }
 const double pain=rig->get("pain");
 if(!first_person&&pain>0){int chest=bone("Chest");Vector3 direction=rig->get("pain_direction");if(chest>=0){Quaternion bend=Quaternion(right,pain*(.09+direction.z*.12))*Quaternion(forward,pain*direction.x*.12);sk->set_bone_pose_rotation(chest,sk->get_bone_pose_rotation(chest)*bend);}if(head>=0)sk->set_bone_pose_rotation(head,sk->get_bone_pose_rotation(head)*Quaternion(right,-pain*.10));}
}
