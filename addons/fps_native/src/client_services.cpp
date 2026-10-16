#include "client_services.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/ip.hpp>
#include <godot_cpp/classes/config_file.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <atomic>
#include <chrono>
#include <cmath>
#include <algorithm>
using namespace godot;
namespace {
constexpr int64_t MAX_ASSET=25000000,CACHE_LIMIT=1000000000;
std::atomic<uint64_t> serial{0};
bool hash_valid(const String &s){if(s.length()!=64)return false;for(int i=0;i<64;++i)if(!((s[i]>='0'&&s[i]<='9')||(s[i]>='a'&&s[i]<='f')))return false;return true;}
String unique_path(const String &base){return base+String(".")+String::num_int64(OS::get_singleton()->get_process_id())+String(".")+String::num_uint64(++serial)+String(".tmp");}
Dictionary failure(const String &message){Dictionary d;d["error"]=message;return d;}
Dictionary inspect_for_cache(const String &path,const String &hash,const String &cache){
 Dictionary info=FPSClientServices::avatar_inspect(path,hash);if(info.has("error"))return info;
 int64_t total=0;auto files=DirAccess::get_files_at(cache);
 for(int i=0;i<files.size();++i)if(String(files[i]).get_extension()=="utavatar"){
  Ref<FileAccess> f=FileAccess::open(cache.path_join(files[i]),FileAccess::READ);if(f.is_valid())total+=f->get_length();
 }
 Ref<FileAccess> existing=FileAccess::open(cache.path_join(hash+String(".utavatar")),FileAccess::READ);
 int64_t old=existing.is_valid()?int64_t(existing->get_length()):0;
 return total-old+int64_t(info["size"])>CACHE_LIMIT?failure("Avatar cache is full (1 GB)."):info;
}
}
void FPSClientServices::_bind_methods(){
 ClassDB::bind_method(D_METHOD("configure","cache","profiles"),&FPSClientServices::configure,DEFVAL(String("user://cq_native_profiles.cfg")));
 ClassDB::bind_method(D_METHOD("reset"),&FPSClientServices::reset);
 ClassDB::bind_method(D_METHOD("resolve_start","host","port"),&FPSClientServices::resolve_start);
 ClassDB::bind_method(D_METHOD("connection_poll"),&FPSClientServices::connection_poll);
 ClassDB::bind_method(D_METHOD("resume_token"),&FPSClientServices::resume_token);
 ClassDB::bind_method(D_METHOD("save_resume","token"),&FPSClientServices::save_resume);
 ClassDB::bind_method(D_METHOD("set_catalog","catalog"),&FPSClientServices::set_catalog);
 ClassDB::bind_method(D_METHOD("queue_downloads","hashes"),&FPSClientServices::queue_downloads);
 ClassDB::bind_method(D_METHOD("pending_downloads"),&FPSClientServices::pending_downloads);
 ClassDB::bind_method(D_METHOD("transfer_control","type","data","now"),&FPSClientServices::transfer_control);
 ClassDB::bind_method(D_METHOD("transfer_chunk","bytes","now"),&FPSClientServices::transfer_chunk,DEFVAL(int64_t(0)));
 ClassDB::bind_method(D_METHOD("offer","hash","path","size"),&FPSClientServices::offer);
 ClassDB::bind_method(D_METHOD("transfer_poll","now"),&FPSClientServices::transfer_poll);
 ClassDB::bind_method(D_METHOD("upload_sent","ok"),&FPSClientServices::upload_sent);
 ClassDB::bind_method(D_METHOD("stats"),&FPSClientServices::stats);
 ClassDB::bind_static_method("FPSClientServices",D_METHOD("avatar_read","path"),&FPSClientServices::avatar_read);
 ClassDB::bind_static_method("FPSClientServices",D_METHOD("avatar_inspect","path","hash"),&FPSClientServices::avatar_inspect,DEFVAL(String()));
}
Error FPSClientServices::configure(const String &cache,const String &profiles){
 if(cache.is_empty()||profiles.is_empty()||!requested_.is_empty()||!upload_hash_.is_empty()||(validation_.valid()&&job_generation_==generation_))return ERR_INVALID_PARAMETER;
 cache_=ProjectSettings::get_singleton()->globalize_path(cache).simplify_path();profiles_=profiles;
 return DirAccess::make_dir_recursive_absolute(cache_);
}
void FPSClientServices::cancel_query(){if(query_!=-1){IP::get_singleton()->erase_resolve_item(query_);query_=-1;}resolving_=false;}
void FPSClientServices::discard_download(){download_file_.unref();if(!temporary_.is_empty())DirAccess::remove_absolute(temporary_);temporary_="";download_hash_="";requested_="";offset_=size_=0;last_progress_=-1;}
void FPSClientServices::reset(){
 ++generation_;cancel_query();discard_download();upload_file_.unref();upload_hash_="";upload_packet_.clear();upload_pending_=upload_allowed_=false;upload_offset_=upload_size_=retry_=clock_=0;upload_progress_=-1;catalog_.clear();queue_.clear();waiting_.clear();packets_.clear();host_="";endpoint_="";
 // An in-flight bounded validation is collected/discarded by poll; reset never waits.
}
FPSClientServices::~FPSClientServices(){reset();if(validation_.valid()){validation_.wait();validation_.get();if(!job_path_.is_empty())DirAccess::remove_absolute(job_path_);}}
Error FPSClientServices::resolve_start(const String &host,int port){
 cancel_query();host_=host.strip_edges();endpoint_="";port_=port;
 if(host_.is_empty()||host_.length()>253||port<1024||port>65535)return ERR_INVALID_PARAMETER;
 if(!host_.is_valid_ip_address()){query_=IP::get_singleton()->resolve_hostname_queue_item(host_,IP::TYPE_IPV4);if(query_==-1)return ERR_CANT_RESOLVE;}
 resolving_=true;return OK;
}
Dictionary FPSClientServices::connection_poll(){
 Dictionary out;out["ready"]=false;if(!resolving_)return out;
 if(query_!=-1){auto status=IP::get_singleton()->get_resolve_item_status(query_);if(status==IP::RESOLVER_STATUS_WAITING||status==IP::RESOLVER_STATUS_NONE)return out;
  host_=IP::get_singleton()->get_resolve_item_address(query_);cancel_query();if(status!=IP::RESOLVER_STATUS_DONE||!host_.is_valid_ip_address())return failure("Cannot resolve server.");
 }
 resolving_=false;endpoint_=host_+String(":")+String::num_int64(port_);out["ready"]=true;out["address"]=host_;out["port"]=port_;out["endpoint"]=endpoint_;return out;
}
String FPSClientServices::resume_token()const{
 if(endpoint_.is_empty())return String();Ref<ConfigFile> config;config.instantiate();if(config->load(profiles_)!=OK)return String();Variant value=config->get_value("sessions",endpoint_,String());if(value.get_type()!=Variant::STRING)return String();String token=value;return hash_valid(token)?token:String();
}
Error FPSClientServices::save_resume(const String &token)const{
 if(endpoint_.is_empty()||!hash_valid(token))return ERR_INVALID_PARAMETER;
 Ref<ConfigFile> config;config.instantiate();config->load(profiles_);config->set_value("sessions",endpoint_,token);
 String path=ProjectSettings::get_singleton()->globalize_path(profiles_);String temporary=unique_path(path);Error result=config->save(temporary);if(result==OK)result=DirAccess::rename_absolute(temporary,path);if(FileAccess::file_exists(temporary))DirAccess::remove_absolute(temporary);return result;
}
void FPSClientServices::set_catalog(const Dictionary &catalog){catalog_.clear();Array keys=catalog.keys();for(int i=0;i<keys.size()&&catalog_.size()<4096;++i){if(keys[i].get_type()!=Variant::STRING)continue;String hash=keys[i];if(!hash_valid(hash)||catalog[hash].get_type()!=Variant::DICTIONARY)continue;Dictionary row=catalog[hash];Variant size=row.get("size",Variant());if((size.get_type()!=Variant::INT&&size.get_type()!=Variant::FLOAT)||!std::isfinite(double(size))||double(size)!=std::floor(double(size))||double(size)<16||double(size)>MAX_ASSET)continue;Dictionary bounded;bounded["size"]=int64_t(size);catalog_[hash]=bounded;}}
void FPSClientServices::queue_downloads(const Array &hashes){for(int i=0;i<hashes.size()&&waiting_.size()<256;++i){if(hashes[i].get_type()!=Variant::STRING)continue;String hash=hashes[i];if(hash_valid(hash)&&catalog_.has(hash)&&waiting_.insert(hash).second)queue_.push_back(hash);}}
Array FPSClientServices::pending_downloads()const{Array out;for(const auto &hash:waiting_)out.push_back(hash);return out;}
void FPSClientServices::packet(int type,const Dictionary &data){Dictionary p;p["type"]=type;p["data"]=data;packets_.push_back(p);}
String FPSClientServices::transfer_control(int type,const Dictionary &data,int64_t now){
 String hash=data.get("hash",String());
 if(type==12){
  if(cache_.is_empty())return "Avatar cache is not configured.";
  if(hash!=requested_||!catalog_.has(hash)||download_file_.is_valid())return "Unexpected avatar transfer.";
  Variant length=data.get("size",Variant());Dictionary row=catalog_[hash];if((length.get_type()!=Variant::INT&&length.get_type()!=Variant::FLOAT)||double(length)!=double(row["size"]))return "Invalid avatar transfer size.";
  size_=row["size"];offset_=0;last_progress_=now;download_hash_=hash;temporary_=unique_path(cache_.path_join(hash+String(".native")));download_file_=FileAccess::open(temporary_,FileAccess::WRITE);if(download_file_.is_null()){discard_download();return "Cannot save avatar download.";}
 }else if(type==14){
  if(hash!=download_hash_||download_file_.is_null()||offset_!=size_||validation_.valid())return "Incomplete avatar transfer.";
  download_file_->flush();Error error=download_file_->get_error();download_file_.unref();if(error!=OK){discard_download();return "Avatar download write failed.";}
  job_hash_=hash;job_path_=temporary_;job_generation_=generation_;String path=job_path_;String expected=job_hash_;String cache=cache_;validation_=std::async(std::launch::async,[path,expected,cache](){return inspect_for_cache(path,expected,cache);});
  temporary_="";download_hash_="";requested_="";offset_=size_=0;
 }else if(type==16&&hash==upload_hash_&&!hash.is_empty()){
  if(bool(data.get("busy",false))){retry_=now+2000;upload_allowed_=false;upload_progress_=now;}
  else if(bool(data.get("upload",false))){upload_allowed_=true;retry_=0;upload_progress_=now;}
  else {Dictionary select;select["hash"]=hash;packet(17,select);upload_file_.unref();upload_hash_="";upload_packet_.clear();upload_pending_=upload_allowed_=false;upload_offset_=upload_size_=retry_=0;upload_progress_=-1;}
 }
 return String();
}
String FPSClientServices::transfer_chunk(const PackedByteArray &bytes,int64_t now){
 if(download_file_.is_null()||bytes.size()<=4||bytes.size()>32772)return "Invalid avatar transfer.";
 auto*p=bytes.ptr();uint32_t offset=uint32_t(p[0])|uint32_t(p[1])<<8|uint32_t(p[2])<<16|uint32_t(p[3])<<24;
 if(offset!=offset_||offset_+bytes.size()-4>size_)return "Invalid avatar transfer offset.";
 download_file_->store_buffer(bytes.slice(4));if(download_file_->get_error()!=OK)return "Avatar download write failed.";offset_+=bytes.size()-4;last_progress_=now;return String();
}
String FPSClientServices::offer(const String &hash,const String &path,int64_t size){
 if(!hash_valid(hash)||size<16||size>MAX_ASSET)return "Invalid avatar offer.";
 Dictionary data;data["hash"]=hash;if(catalog_.has(hash)){packet(17,data);return String();}if(!upload_hash_.is_empty())return String();
 upload_file_=FileAccess::open(path,FileAccess::READ);if(upload_file_.is_null()||upload_file_->get_length()!=uint64_t(size)){upload_file_.unref();return "Cannot open avatar upload.";}
 upload_hash_=hash;upload_progress_=-1;upload_size_=size;upload_offset_=retry_=0;upload_allowed_=upload_pending_=false;data["size"]=size;packet(15,data);return String();
}
Array FPSClientServices::transfer_poll(int64_t now){
 Array out;clock_=now;
 if(!upload_hash_.is_empty()){
  if(upload_progress_<0)upload_progress_=now;
  if(now-upload_progress_>30000){upload_file_.unref();upload_hash_="";upload_packet_.clear();upload_pending_=upload_allowed_=false;upload_offset_=upload_size_=retry_=0;out.push_back(failure("Avatar upload timed out."));return out;}
 }
 if((!requested_.is_empty()||download_file_.is_valid())&&last_progress_>=0&&now-last_progress_>30000){String hash=requested_;discard_download();waiting_.erase(hash);out.push_back(failure("Avatar download timed out."));return out;}
 if(validation_.valid()&&validation_.wait_for(std::chrono::seconds(0))==std::future_status::ready){
  Dictionary info=validation_.get();String hash=job_hash_,path=job_path_;job_hash_="";job_path_="";
  if(job_generation_==generation_){
   String destination=cache_.path_join(hash+String(".utavatar"));
   if(!info.has("error")){
    if(DirAccess::rename_absolute(path,destination)!=OK)info=failure("Cannot publish verified avatar.");
    else {info["hash"]=hash;info["path"]=destination;Dictionary event;event["installed"]=info;out.push_back(event);}
   }
   if(info.has("error"))out.push_back(info);waiting_.erase(hash);
  }
  if(FileAccess::file_exists(path))DirAccess::remove_absolute(path);
 }
 if(requested_.is_empty()&&download_file_.is_null()&&!validation_.valid()&&!queue_.empty()){
  requested_=queue_.front();queue_.pop_front();last_progress_=now;Dictionary get;get["hash"]=requested_;packet(11,get);
 }
 if(!upload_hash_.is_empty()&&retry_>0&&now>=retry_){retry_=0;Dictionary offer;offer["hash"]=upload_hash_;offer["size"]=upload_size_;packet(15,offer);}
 out.append_array(packets_);packets_.clear();
 if(upload_allowed_&&!upload_hash_.is_empty()&&upload_offset_<upload_size_){
  if(!upload_pending_){
   int64_t count=std::min<int64_t>(32768,upload_size_-upload_offset_);auto bytes=upload_file_->get_buffer(count);if(bytes.size()!=count){out.push_back(failure("Avatar upload source changed or cannot be read."));upload_allowed_=false;return out;}
   upload_packet_.resize(4);for(int i=0;i<4;++i)upload_packet_.ptrw()[i]=uint8_t(uint64_t(upload_offset_)>>(8*i));upload_packet_.append_array(bytes);upload_pending_=true;
  }
  Dictionary chunk;chunk["type"]=23;chunk["bytes"]=upload_packet_;chunk["channel"]=3;out.push_back(chunk);
 }
 return out;
}
void FPSClientServices::upload_sent(bool ok){if(!ok||!upload_pending_)return;upload_offset_+=upload_packet_.size()-4;upload_progress_=clock_;upload_pending_=false;upload_packet_.clear();if(upload_offset_==upload_size_)upload_allowed_=false;}
Dictionary FPSClientServices::stats()const{Dictionary d;d["generation"]=generation_;d["resolving"]=resolving_;d["pending"]=int64_t(waiting_.size());d["download_offset"]=offset_;d["upload_offset"]=upload_offset_;d["validating"]=validation_.valid();d["buffered_download_bytes"]=0;d["temporary"]=temporary_;return d;}
