#include "poses.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;
void FPSPose::_bind_methods() {
 ClassDB::bind_method(D_METHOD("configure_morphs","channels"),&FPSPose::configure_morphs);
 ClassDB::bind_method(D_METHOD("compose_morphs","eyes","mouth","dead"),&FPSPose::compose_morphs);
 ClassDB::bind_method(D_METHOD("interpolate_tracking","shown","target","delta"),&FPSPose::interpolate_tracking);
 ClassDB::bind_method(D_METHOD("prepare_live","skeleton","rig","ids","rest","rotations","floor_heights","sample_floor"),&FPSPose::prepare_live);
 ClassDB::bind_method(D_METHOD("solve","skeleton","upper","lower","end","target","pole"),&FPSPose::solve);
 ClassDB::bind_method(D_METHOD("rotate_toward","skeleton","index","source","destination"),&FPSPose::rotate_toward);
 ClassDB::bind_method(D_METHOD("orient","skeleton","index","world_basis"),&FPSPose::orient);
 ClassDB::bind_method(D_METHOD("fingers","skeleton","indices","rest","curls"),&FPSPose::fingers);
 ClassDB::bind_method(D_METHOD("capture","skeleton","ids","poses","moving","optimized"),&FPSPose::capture);
 ClassDB::bind_method(D_METHOD("blend","skeleton","rows","shown","weight"),&FPSPose::blend);
}
void FPSPose::rotate_toward(Skeleton3D *sk,int index,Vector3 source,Vector3 destination) {
 if(!sk || index<0 || index>=sk->get_bone_count() || source.length_squared()<.000001 || destination.length_squared()<.000001)return;
 Basis basis=sk->get_bone_global_pose(index).basis.orthonormalized();
 Quaternion change(source.normalized(),destination.normalized());
 int parent=sk->get_bone_parent(index);
 Basis parent_basis=parent>=0?sk->get_bone_global_pose(parent).basis.orthonormalized():Basis();
 sk->set_bone_pose_rotation(index,(parent_basis.inverse()*Basis(change)*basis).get_rotation_quaternion());
}
void FPSPose::solve(Skeleton3D *sk,int a,int b,int c,Vector3 target_world,Vector3 pole_world) {
 if(!sk || a<0 || b<0 || c<0 || a>=sk->get_bone_count() || b>=sk->get_bone_count() || c>=sk->get_bone_count())return;
 Vector3 origin=sk->get_bone_global_pose(a).origin,middle=sk->get_bone_global_pose(b).origin,tip=sk->get_bone_global_pose(c).origin;
 double l1=origin.distance_to(middle),l2=middle.distance_to(tip);
 if(std::min(l1,l2)<.0001)return;
 Vector3 target=sk->to_local(target_world),direction=(target-origin).normalized();
 if(direction.length()<.5)return;
 // Godot clampf uses min(max(value,min),max), including very short chains.
 double distance=std::min(std::max(double(origin.distance_to(target)),std::abs(l1-l2)+.001),l1+l2-.001);
 Vector3 pole=sk->to_local(pole_world)-origin;
 Vector3 perpendicular=(pole-direction*pole.dot(direction)).normalized();
 if(perpendicular.length()<.5)perpendicular=direction.cross(Vector3(1,0,0)).normalized();
 double along=(l1*l1-l2*l2+distance*distance)/(2*distance),height=std::sqrt(std::max(0.,l1*l1-along*along));
 Vector3 elbow=origin+direction*along+perpendicular*height;
 rotate_toward(sk,a,middle-origin,elbow-origin);
 middle=sk->get_bone_global_pose(b).origin;tip=sk->get_bone_global_pose(c).origin;
 rotate_toward(sk,b,tip-middle,origin+direction*distance-middle);
}
void FPSPose::orient(Skeleton3D *sk,int index,Basis world) {
 if(!sk || index<0 || index>=sk->get_bone_count())return;
 int parent=sk->get_bone_parent(index);
 Basis parent_basis=parent>=0?sk->get_bone_global_pose(parent).basis.orthonormalized():Basis();
 sk->set_bone_pose_rotation(index,(parent_basis.inverse()*sk->get_global_basis().orthonormalized().inverse()*world.orthonormalized()).get_rotation_quaternion());
}
void FPSPose::fingers(Skeleton3D *sk,const PackedInt32Array &indices,const Array &rest,const PackedFloat32Array &curls) {
 if(!sk || indices.size()!=15 || indices.size()!=rest.size())return;
 for(int i=0;i<indices.size();++i) {
  int index=indices[i];if(index<0 || index>=sk->get_bone_count())continue;
  double curl=curls.size()==5?double(curls[i/3])*1.25:.8;
  sk->set_bone_pose_rotation(index,Quaternion(rest[i])*Quaternion(Vector3(1,0,0),curl));
 }
}
void FPSPose::capture(Skeleton3D *sk,const Dictionary &ids,Dictionary poses,const Array &moving,bool optimized) {
 if(!sk)return;
 Array indices=ids.values();
 for(int i=0;i<indices.size();++i) {
  int index=indices[i];if(index<0 || index>=sk->get_bone_count())continue;
  if(optimized && poses.has(index)) {
   Array row=poses[index];row[0]=sk->get_bone_pose_rotation(index);
   if(moving.has(index))row[1]=sk->get_bone_pose_position(index);
  } else {Array row;row.push_back(sk->get_bone_pose_rotation(index));row.push_back(sk->get_bone_pose_position(index));poses[index]=row;}
 }
}
void FPSPose::blend(Skeleton3D *sk,const Array &rows,Dictionary shown,double weight) {
 if(!sk)return;
 for(int i=0;i<rows.size();++i) {
  Array row=rows[i];if(row.size()!=8)continue;
  int index=row[0];if(index<0 || index>=sk->get_bone_count() || !shown.has(index))continue;
  Quaternion rotation=bool(row[5]) && weight<1?Quaternion(row[1]).slerp(Quaternion(row[2]),weight):Quaternion(row[2]);
  sk->set_bone_pose_rotation(index,rotation);Array value=shown[index];value[0]=rotation;
  if(bool(row[7])) {
   Vector3 position=bool(row[6]) && weight<1?Vector3(row[3]).lerp(Vector3(row[4]),weight):Vector3(row[4]);
   sk->set_bone_pose_position(index,position);value[1]=position;
  }
 }
}
