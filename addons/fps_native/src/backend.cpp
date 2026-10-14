#include "backend.h"
#include "codec.h"
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <chrono>
#ifdef __linux__
#include <sys/socket.h>
#include <netinet/in.h>
#include <dirent.h>
#endif
#include <unordered_map>
using namespace godot;
namespace {constexpr double INF=std::numeric_limits<double>::infinity();}
void FPSBackend::_bind_methods(){
 ClassDB::bind_method(D_METHOD("configure_hitboxes","rows"),&FPSBackend::configure_hitboxes);
 ClassDB::bind_method(D_METHOD("set_workers","count"),&FPSBackend::set_workers);
 ClassDB::bind_method(D_METHOD("get_workers"),&FPSBackend::get_workers);
 ClassDB::bind_method(D_METHOD("set_parallel_threshold","pairs"),&FPSBackend::set_parallel_threshold);
 ClassDB::bind_method(D_METHOD("player_fraction","start","end","height","yaw","radius"),&FPSBackend::player_fraction);
 ClassDB::bind_method(D_METHOD("player_axis","impact","height","yaw"),&FPSBackend::player_axis);
 ClassDB::bind_method(D_METHOD("player_head","point","height","yaw","radius"),&FPSBackend::player_head);
 ClassDB::bind_method(D_METHOD("range_candidates","positions","teams","observers","targets","radii"),&FPSBackend::range_candidates);
 ClassDB::bind_method(D_METHOD("rewind","before","after","current","weight"),&FPSBackend::rewind);
 ClassDB::bind_method(D_METHOD("submit_snapshot","records","header","token"),&FPSBackend::submit_snapshot);
 ClassDB::bind_method(D_METHOD("poll_snapshots"),&FPSBackend::poll_snapshots);
 ClassDB::bind_method(D_METHOD("valid_transform","value"),&FPSBackend::valid_transform);
 ClassDB::bind_method(D_METHOD("validate_pose","value"),&FPSBackend::validate_pose);
 ClassDB::bind_method(D_METHOD("room_request","head"),&FPSBackend::room_request);
 ClassDB::bind_method(D_METHOD("record_history","time","actors"),&FPSBackend::record_history);
 ClassDB::bind_method(D_METHOD("history_state","now","rewind","actors"),&FPSBackend::history_state);
 ClassDB::bind_method(D_METHOD("clear_history"),&FPSBackend::clear_history);
 ClassDB::bind_method(D_METHOD("build_targets","ids","current","previous"),&FPSBackend::build_targets);
 ClassDB::bind_method(D_METHOD("get_target_overflow"),&FPSBackend::get_target_overflow);
 ClassDB::bind_method(D_METHOD("target_candidates","start","end","radius"),&FPSBackend::target_candidates);
 ClassDB::bind_method(D_METHOD("tune_udp_buffer","port","bytes"),&FPSBackend::tune_udp_buffer);
 ClassDB::bind_method(D_METHOD("shutdown"),&FPSBackend::shutdown);
}
FPSBackend::~FPSBackend(){shutdown();}
void FPSBackend::stop_workers(){
 {std::lock_guard<std::mutex> lock(mutex);stopping=true;}wake.notify_all();
 for(auto &thread:workers)thread.join();workers.clear();stopping=false;
}
void FPSBackend::set_workers(int n){std::lock_guard<std::mutex> guard(dispatch_mutex);stop_workers();threads=std::clamp(n,1,10);}
void FPSBackend::parallel(size_t n,const std::function<void(size_t)> &fn,int threshold){
 std::lock_guard<std::mutex> guard(dispatch_mutex);
 if(threads==1||n<size_t(threshold>0?threshold:parallel_threshold)){for(size_t i=0;i<n;++i)fn(i);return;}
 if(workers.empty())for(int i=0;i<threads;++i)workers.emplace_back([this]{
  size_t seen=0;std::unique_lock<std::mutex> lock(mutex);
  while(true){wake.wait(lock,[&]{return stopping||generation!=seen;});if(stopping)return;seen=generation;
   while(next<count){size_t first=next;size_t last=std::min(count,first+std::max(size_t(1),(count+threads*4-1)/(threads*4)));next=last;lock.unlock();for(size_t i=first;i<last;++i)job(i);lock.lock();}
   if(++finished==workers.size())done.notify_one();
  }
 });
 std::unique_lock<std::mutex> lock(mutex);job=fn;count=n;next=0;finished=0;++generation;wake.notify_all();
 done.wait(lock,[&]{return finished==workers.size();});job={};
}
void FPSBackend::configure_hitboxes(const Array &rows){
 if(rows.size()!=101)return;
 for(int i=0;i<101;++i){anatomy[i].clear();Array list=rows[i];for(int j=0;j<list.size();++j){Dictionary row=list[j];Transform3D pose=row["pose"];Vector3 size=row["size"];anatomy[i].push_back({pose,pose.affine_inverse(),size*.5});}}
}
const std::vector<FPSBackend::Part> &FPSBackend::parts(double height) const{return anatomy[std::clamp(int(std::round(height*100)),65,165)-65];}
double FPSBackend::box(Vector3 start,Vector3 end,Vector3 half,double radius){
 Vector3 motion=end-start;double enter=0,leave=1;
 for(int axis=0;axis<3;++axis){double extent=half[axis]+radius+.000001;
  if(std::abs(motion[axis])<1e-10){if(std::abs(start[axis])>extent)return INF;}
  else{double a=(-extent-start[axis])/motion[axis],b=(extent-start[axis])/motion[axis];enter=std::max(enter,std::min(a,b));leave=std::min(leave,std::max(a,b));if(enter>leave)return INF;}
 }
 if(radius<=0)return enter;
 std::vector<double> cuts{enter,leave};
 for(int axis=0;axis<3;++axis){if(std::abs(motion[axis])<1e-10)continue;for(double sign:{-1.,1.}){double t=(sign*half[axis]-start[axis])/motion[axis];if(t>enter&&t<leave)cuts.push_back(t);}}
 std::sort(cuts.begin(),cuts.end());Vector3 p=start.lerp(end,enter);
 if(p.distance_squared_to(p.clamp(-half,half))<=radius*radius+1e-10)return enter;
 for(size_t i=0;i+1<cuts.size();++i){double low=cuts[i],high=cuts[i+1];Vector3 mid=start.lerp(end,(low+high)*.5),offset,velocity;
  for(int axis=0;axis<3;++axis)if(std::abs(mid[axis])>half[axis]){offset[axis]=start[axis]-(mid[axis]>0?1:-1)*half[axis];velocity[axis]=motion[axis];}
  double a=velocity.length_squared(),b=offset.dot(velocity),c=offset.length_squared()-radius*radius;if(a<1e-12)continue;double d=b*b-a*c;if(d<0)continue;
  double t=(-b-std::sqrt(d))/a;if(t>=low-1e-7&&t<=high+1e-7)return std::clamp(t,low,high);
 }return INF;
}
double FPSBackend::player_fraction(Vector3 start,Vector3 end,double height,double yaw,double radius) const{
 Basis inverse(Vector3(0,1,0),-yaw);start=inverse.xform(start);end=inverse.xform(end);
 if(!std::isfinite(box(start-Vector3(0,.8,0),end-Vector3(0,.8,0),Vector3(1.5,.9,1.5),radius)))return INF;
 double first=INF;for(const auto &part:parts(height))first=std::min(first,box(part.inverse.xform(start),part.inverse.xform(end),part.half,radius));return first;
}
Vector3 FPSBackend::player_axis(Vector3 impact,double height,double yaw) const{
 Vector3 local=Basis(Vector3(0,1,0),-yaw).xform(impact),closest;double distance=INF;
 for(const auto &part:parts(height)){Vector3 point=part.pose.xform(part.inverse.xform(local).clamp(-part.half,part.half));double gap=local.distance_squared_to(point);if(gap<distance){distance=gap;closest=part.pose.origin;}}
 return Vector3(0,closest.y,0);
}
bool FPSBackend::player_head(Vector3 point,double height,double yaw,double radius) const{
 const auto &list=parts(height);if(list.size()<2)return false;const auto &head=list[1];Vector3 local=head.inverse.xform(Basis(Vector3(0,1,0),-yaw).xform(point));return local.distance_squared_to(local.clamp(-head.half,head.half))<=radius*radius+1e-8;
}
Array FPSBackend::range_candidates(const PackedVector3Array &positions,const PackedInt32Array &teams,const PackedInt32Array &observers,const PackedInt32Array &targets,const PackedFloat64Array &radii){
 size_t n=positions.size();if(teams.size()!=int64_t(n)||observers.size()!=int64_t(n)||targets.size()!=int64_t(n)||radii.size()!=int64_t(n)||n>4096)return Array();
 // Workers only see independent POD copies, never Godot containers or live nodes.
 std::vector<Vector3> p(n);std::vector<int> t(n),o(n),eligible(n);std::vector<double> r(n);std::vector<uint8_t> matches(n*n);
 for(size_t i=0;i<n;++i){p[i]=positions[i];t[i]=teams[i];o[i]=observers[i];eligible[i]=targets[i];r[i]=radii[i];}
 parallel(n*n,[&](size_t pair){size_t i=pair/n,j=pair%n;matches[pair]=i!=j&&o[i]&&eligible[j]&&t[i]>=0&&t[i]<=1&&t[i]!=t[j]&&r[i]>0&&p[i].distance_squared_to(p[j])<=r[i]*r[i];});
 Array result;for(size_t i=0;i<n;++i){PackedInt32Array row;for(size_t j=0;j<n;++j)if(matches[i*n+j])row.append(j);result.append(row);}return result;
}
Dictionary FPSBackend::rewind(const Dictionary &before,const Dictionary &after,const Dictionary &current,double weight) const{
 Dictionary positions,heights,yaws,result;Array ids=current.keys();
 for(int i=0;i<ids.size();++i){Variant id=ids[i];Dictionary c=current[id],a=before.get(id,Dictionary()),b=after.get(id,Dictionary());
  if(a.get("serial",-1)!=c["serial"]||b.get("serial",-1)!=c["serial"])continue;
  Vector3 p=a["position"],q=b["position"];if(p.distance_to(q)>3.)continue;
  positions[id]=p.lerp(q,weight);heights[id]=Math::lerp(double(a.get("height",1.65)),double(b.get("height",1.65)),weight);
  yaws[id]=Math::lerp_angle(double(a.get("yaw",c.get("yaw",0.))),double(b.get("yaw",c.get("yaw",0.))),weight);
 }result["positions"]=positions;result["heights"]=heights;result["yaws"]=yaws;return result;
}
bool FPSBackend::submit_snapshot(const Array &records,const Array &header,int64_t token){
 if(header.size()!=3||records.size()>32768||Variant(header[0]).get_type()!=Variant::INT||Variant(header[1]).get_type()!=Variant::INT||Variant(header[2]).get_type()!=Variant::FLOAT)return false;
 for(int i=0;i<records.size();++i){Variant value=records[i];if(value.get_type()!=Variant::ARRAY)return false;Array row=value;if(row.size()<3||Variant(row[0]).get_type()!=Variant::INT)return false;}
 std::lock_guard<std::mutex> lock(encode_mutex);
 if(encode_stopping||pending.size()+completed.size()+size_t(encoding)>=2)return false;
 // Deep-copy before leaving the main thread; the encoder owns all mutable data.
 pending.push_back({records.duplicate(true),header.duplicate(true),token});
 if(!encoder.joinable())encoder=std::thread(&FPSBackend::encode_loop,this);encode_wake.notify_one();return true;
}
void FPSBackend::encode_loop(){
 Ref<FPSCodec> codec;codec.instantiate();int64_t last_token=-1,last_epoch=-1;
 std::unordered_map<std::string,std::pair<PackedByteArray,double>> cache;
 while(true){SnapshotJob task;
  {std::unique_lock<std::mutex> lock(encode_mutex);encode_wake.wait(lock,[&]{return encode_stopping||!pending.empty();});if(encode_stopping)return;task=pending.front();pending.pop_front();encoding=true;}
  auto began=std::chrono::steady_clock::now();
  int64_t epoch=task.header[0];double time=task.header[2];if(task.token!=last_token||epoch!=last_epoch){cache.clear();last_token=task.token;last_epoch=epoch;}
  // Frozen per-job records contain only network values. No worker writes
  // shared Godot containers: each produces a private byte buffer, merged here.
  std::vector<Variant> inputs;std::vector<PackedByteArray> outputs(task.records.size());
  inputs.reserve(task.records.size());for(int i=0;i<task.records.size();++i)inputs.push_back(task.records[i]);
  parallel(inputs.size(),[&](size_t i){Array row=inputs[i];bool player=row.size()==5&&row[0]==Variant(2);PackedByteArray bytes;bytes.append(player?1:0);bytes.append_array(player?codec->encode(row):UtilityFunctions::var_to_bytes(row));outputs[i]=bytes;},64);
  Array batch,filtered;for(const auto &bytes:outputs)batch.append(bytes);
  for(int i=0;i<batch.size();++i){Array row=task.records[i];PackedByteArray bytes=batch[i];int64_t kind=row[0];
   bool eligible=(kind==0||kind==1||kind==4)&&!(kind==0&&(row[1]==Variant(2)||row[1]==Variant(3)||row[1]==Variant(12)||row[1]==Variant(13)));
   if(eligible){String key=String::num_int64(kind)+":"+UtilityFunctions::str(row[1]);std::string native_key=key.utf8().get_data();auto found=cache.find(native_key);
    if(found!=cache.end()&&found->second.first==bytes&&time-found->second.second<1.)continue;cache[native_key]={bytes,time};}
   filtered.append(bytes);
  }
  Dictionary result=codec->pack_records(filtered,task.header);result["token"]=task.token;result["epoch"]=epoch;result["sequence"]=task.header[1];result["time"]=time;result["encode_usec"]=int64_t(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-began).count());
  {std::lock_guard<std::mutex> lock(encode_mutex);encoding=false;completed.push_back(result);}
 }
}
Array FPSBackend::poll_snapshots(){std::lock_guard<std::mutex> lock(encode_mutex);Array result;for(const auto &row:completed)result.append(row);completed.clear();return result;}
void FPSBackend::shutdown(){
 {std::lock_guard<std::mutex> lock(encode_mutex);encode_stopping=true;}encode_wake.notify_all();if(encoder.joinable())encoder.join();pending.clear();completed.clear();stop_workers();
}

namespace {
bool grid_safe(Vector3 p){return p.is_finite()&&std::abs(p.x)<=1000000.&&std::abs(p.z)<=1000000.;}
uint64_t grid_key(int64_t x,int64_t z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
bool grid_large(int64_t lx,int64_t lz,int64_t hx,int64_t hz){int64_t w=hx-lx+1,d=hz-lz+1;return w<1||d<1||w>64||d>64||w*d>64;}
}
void FPSBackend::build_targets(const Array &ids,const PackedVector3Array &current,const PackedVector3Array &previous){
 target_ids.clear();target_cells.clear();target_overflow.clear();if(ids.size()!=current.size()||ids.size()!=previous.size())return;
 for(int i=0;i<ids.size();++i){target_ids.push_back(int64_t(ids[i]));Vector3 p=current[i],q=previous[i];
  if(!grid_safe(p)||!grid_safe(q)){target_overflow.push_back(i);continue;}
  int64_t lx=std::floor((std::min(p.x,q.x)-1.500001)/4),lz=std::floor((std::min(p.z,q.z)-1.500001)/4),hx=std::floor((std::max(p.x,q.x)+1.500001)/4),hz=std::floor((std::max(p.z,q.z)+1.500001)/4);
  if(grid_large(lx,lz,hx,hz)){target_overflow.push_back(i);continue;}
  for(int64_t x=lx;x<=hx;++x)for(int64_t z=lz;z<=hz;++z)target_cells[grid_key(x,z)].push_back(i);
 }
}
Array FPSBackend::target_candidates(Vector3 start,Vector3 end,double radius) const{
 Array result;auto all=[&]{for(auto id:target_ids)result.append(id);return result;};
 if(!grid_safe(start)||!grid_safe(end)||!std::isfinite(radius)||radius>1000000.)return all();
 double pad=std::max(0.,radius)+.000001;
 int64_t lx=std::floor((std::min(start.x,end.x)-pad)/4),lz=std::floor((std::min(start.z,end.z)-pad)/4),hx=std::floor((std::max(start.x,end.x)+pad)/4),hz=std::floor((std::max(start.z,end.z)+pad)/4);
 if(grid_large(lx,lz,hx,hz))return all();std::vector<uint8_t> present(target_ids.size());for(auto i:target_overflow)present[i]=1;
 for(int64_t x=lx;x<=hx;++x)for(int64_t z=lz;z<=hz;++z){auto cell=target_cells.find(grid_key(x,z));if(cell!=target_cells.end())for(auto i:cell->second)present[i]=1;}
 for(size_t i=0;i<present.size();++i)if(present[i])result.append(target_ids[i]);return result;
}

void FPSBackend::record_history(double time,const Dictionary &actors){
 if(!history.empty()&&time<history.back().time)history.clear();HistoryFrame frame;frame.time=time;Array ids=actors.keys();frame.actors.reserve(ids.size());
 for(int i=0;i<ids.size();++i){Dictionary row=actors[ids[i]];frame.actors.push_back({int64_t(ids[i]),int64_t(row["serial"]),Vector3(row["position"]),double(row.get("height",1.65)),double(row.get("yaw",0.))});}
 history.push_back(std::move(frame));while(history.size()>2&&(history[1].time<time-.35||history.size()>256))history.pop_front();
}
Dictionary FPSBackend::history_state(double now,double rewind_time,const Dictionary &actors) const{
 Dictionary positions,heights,yaws,result;result["positions"]=positions;result["heights"]=heights;result["yaws"]=yaws;if(rewind_time<=0||history.empty())return result;
 const HistoryFrame *before=&history.front(),*after=nullptr;double at=now-std::clamp(rewind_time,0.,.3);
 for(const auto &frame:history){if(frame.time<=at)before=&frame;else{after=&frame;break;}}
 double weight=std::clamp((at-before->time)/std::max((after?after->time:now)-before->time,.000001),0.,1.);
 std::unordered_map<int64_t,const HistoryActor*> left,right;for(const auto &row:before->actors)left[row.id]=&row;if(after)for(const auto &row:after->actors)right[row.id]=&row;
 Array ids=actors.keys();for(int i=0;i<ids.size();++i){int64_t id=ids[i];Dictionary c=actors[id];auto a=left.find(id);auto b=right.find(id);if(a==left.end()||(after&&b==right.end()))continue;
  HistoryActor current{id,int64_t(c["serial"]),Vector3(c["position"]),double(c.get("height",1.65)),double(c.get("yaw",0.))};const auto &l=*a->second;const auto &r=after?*b->second:current;
  if(l.serial!=current.serial||r.serial!=current.serial||l.position.distance_to(r.position)>3.)continue;
  positions[id]=l.position.lerp(r.position,weight);heights[id]=Math::lerp(l.height,r.height,weight);yaws[id]=Math::lerp_angle(l.yaw,r.yaw,weight);
 }return result;
}

Array FPSBackend::get_target_overflow() const{Array result;for(auto i:target_overflow)result.append(target_ids[i]);return result;}

bool FPSBackend::valid_transform(const Variant &value) const{
 if(value.get_type()!=Variant::TRANSFORM3D)return false;Transform3D t=value;
 if(!t.origin.is_finite()||!t.basis.is_finite()||std::abs(t.basis.determinant()-1.)>.05)return false;
 Vector3 x=t.basis.get_column(0),y=t.basis.get_column(1),z=t.basis.get_column(2);
 return std::abs(x.length()-1.)<=.02&&std::abs(y.length()-1.)<=.02&&std::abs(z.length()-1.)<=.02&&std::abs(x.dot(y))<.02&&std::abs(x.dot(z))<.02&&std::abs(y.dot(z))<.02;
}
Dictionary FPSBackend::validate_pose(const Variant &value) const{
 Dictionary empty;if(value.get_type()!=Variant::DICTIONARY)return empty;Dictionary data=value;
 if(data.size()<5||data.size()>7||!data.has("left_handed")||Variant(data["left_handed"]).get_type()!=Variant::BOOL)return empty;
 Array keys=data.keys();for(int i=0;i<keys.size();++i){Variant k=keys[i];if(k.get_type()!=Variant::STRING&&k.get_type()!=Variant::STRING_NAME)return empty;String key=k;if(key!="head"&&key!="left"&&key!="right"&&key!="weapon"&&key!="left_handed"&&key!="offhand_weapon"&&key!="height")return empty;}
 for(const char *key:{"head","left","right","weapon"})if(!valid_transform(data.get(key,Variant())))return empty;
 Vector3 head=Transform3D(data["head"]).origin;if(Vector2(head.x,head.z).length()>.75||head.y<.05||head.y>3.2)return empty;
 Vector3 center(head.x,std::clamp(double(head.y)-.45,.25,2.7),head.z);
 for(const char *key:{"left","right"})if(Transform3D(data[key]).origin.distance_to(center)>1.55)return empty;
 bool left=data["left_handed"];Transform3D hand=data[left?"left":"right"];
 if(Transform3D(data["weapon"]).origin.distance_to(hand.origin)>.4)return empty;
 if(data.has("offhand_weapon")){Variant off=data["offhand_weapon"];if(!valid_transform(off)||Transform3D(off).origin.distance_to(Transform3D(data[left?"right":"left"]).origin)>.4)return empty;}
 Dictionary result=data.duplicate();if(data.has("height")){Variant height=data["height"];if((height.get_type()!=Variant::FLOAT&&height.get_type()!=Variant::INT)||!std::isfinite(double(height)))return empty;result["height"]=std::clamp(double(height),.8,1.65);}return result;
}
Vector3 FPSBackend::room_request(Vector3 head) const{
 Vector3 horizontal(head.x,0,head.z);if(!head.is_finite()||horizontal.length()>.75)return Vector3();return horizontal.normalized()*std::clamp(double(horizontal.length())-.02,0.,.08);
}

Dictionary FPSBackend::tune_udp_buffer(int port,int bytes) const{
 Dictionary result;result["available"]=false;
#ifdef __linux__
 DIR *directory=opendir("/proc/self/fd");if(!directory)return result;
 while(auto *entry=readdir(directory)){char *end=nullptr;long fd=strtol(entry->d_name,&end,10);if(!end||*end||fd<0)continue;
  int type=0;socklen_t size=sizeof(type);if(getsockopt(fd,SOL_SOCKET,SO_TYPE,&type,&size)||type!=SOCK_DGRAM)continue;
  sockaddr_storage address{};size=sizeof(address);if(getsockname(fd,reinterpret_cast<sockaddr*>(&address),&size))continue;
  int local=address.ss_family==AF_INET?ntohs(reinterpret_cast<sockaddr_in*>(&address)->sin_port):address.ss_family==AF_INET6?ntohs(reinterpret_cast<sockaddr_in6*>(&address)->sin6_port):0;
  if(local!=port)continue;int before=0,after=0;size=sizeof(int);getsockopt(fd,SOL_SOCKET,SO_RCVBUF,&before,&size);
  int requested=std::clamp(bytes,65536,16*1024*1024);int error=setsockopt(fd,SOL_SOCKET,SO_RCVBUF,&requested,sizeof(requested));size=sizeof(int);getsockopt(fd,SOL_SOCKET,SO_RCVBUF,&after,&size);
  result["available"]=true;result["port"]=port;result["before"]=before;result["after"]=after;result["requested"]=requested;result["error"]=error;break;
 }closedir(directory);
#endif
 return result;
}
