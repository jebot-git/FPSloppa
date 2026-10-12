#include "poses.h"
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/core/object.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

void FPSPose::configure_morphs(const Array &channels) {
 morph_channels.clear();
 for(int i=0;i<channels.size();++i){
  Array row=channels[i];Object *object=row[0];
  if(!object)continue;
  MorphChannel channel;channel.mesh=object->get_instance_id();channel.shape=row[1];channel.limit=row[2];channel.row=row;
  Array sources=row[3];
  for(int j=0;j<sources.size();++j){Array source=sources[j];channel.sources.push_back({int(source[0]),double(source[1])});}
  morph_channels.push_back(channel);
 }
}
int64_t FPSPose::compose_morphs(const Array &eyes,const PackedFloat32Array &mouth,bool dead) {
 double weights[17]={};
 for(int i=0;i<12&&i<eyes.size();++i)weights[i]=eyes[i];
 if(!dead)for(int i=0;i<5&&i<mouth.size();++i)weights[i+12]=mouth[i];
 int64_t writes=0;
 for(auto &channel:morph_channels){
  MeshInstance3D *mesh=Object::cast_to<MeshInstance3D>(ObjectDB::get_instance(channel.mesh));
  if(!mesh)continue;
  double value=0;
  for(const auto &source:channel.sources)if(source.index>=0&&source.index<17)value+=weights[source.index]*source.weight;
  value=std::clamp(value,0.,channel.limit);
  double previous=channel.row[4];
  if(std::isnan(previous)||std::abs(value-previous)>.00001){mesh->set_blend_shape_value(channel.shape,value);channel.row[4]=value;++writes;}
 }
 return writes;
}
void FPSPose::interpolate_tracking(Dictionary shown,const Dictionary &target,double delta) {
 const double weight=std::min(1.,delta*22);
 for(const StringName &key:{tracking_head,tracking_left,tracking_right,tracking_weapon})shown[key]=Transform3D(shown[key]).interpolate_with(target[key],weight);
 if(target.has(tracking_offhand))shown[tracking_offhand]=Transform3D(shown.get(tracking_offhand,target[tracking_offhand])).interpolate_with(target[tracking_offhand],weight);
 else shown.erase(tracking_offhand);
 shown[tracking_handed]=target[tracking_handed];shown[tracking_face]=target.get(tracking_face,Dictionary());
 Dictionary next=target.get(tracking_body,Dictionary()),previous=shown.get(tracking_body,Dictionary()),body;
 Array keys=next.keys();
 for(int i=0;i<keys.size();++i){Variant key=keys[i],value=next[key];body[key]=previous.has(key)&&value.get_type()==Variant::TRANSFORM3D?Variant(Transform3D(previous[key]).interpolate_with(value,std::min(1.,delta*18))):value;}
 shown[tracking_body]=body;
}
