#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <deque>
#include <future>
#include <set>
// Connection-scoped I/O; only immutable paths/hashes enter the validation worker.
// Poll returns main-thread commands/results; no worker calls the scene tree.
class FPSClientServices : public godot::RefCounted {
 GDCLASS(FPSClientServices,godot::RefCounted)
 int query_=-1,port_=0;
 int64_t generation_=0,offset_=0,size_=0,upload_size_=0,upload_offset_=0,retry_=0,job_generation_=0,last_progress_=-1,clock_=0,upload_progress_=-1;
 bool resolving_=false,upload_allowed_=false,upload_pending_=false;
 godot::String host_,endpoint_,cache_,profiles_="user://cq_native_profiles.cfg",requested_,download_hash_,temporary_,upload_hash_,job_hash_,job_path_;
 godot::Dictionary catalog_;
 godot::Ref<godot::FileAccess> download_file_,upload_file_;
 std::deque<godot::String> queue_;
 std::set<godot::String> waiting_;
 godot::Array packets_;
 std::future<godot::Dictionary> validation_;
 godot::PackedByteArray upload_packet_;
 void cancel_query();
 void discard_download();
 void packet(int type,const godot::Dictionary &data);
protected:static void _bind_methods();
public:
 godot::Error configure(const godot::String &cache,const godot::String &profiles);
 void reset();
 godot::Error resolve_start(const godot::String &host,int port);
 godot::Dictionary connection_poll();
 godot::String resume_token() const;
 godot::Error save_resume(const godot::String &token) const;
 void set_catalog(const godot::Dictionary &catalog);
 void queue_downloads(const godot::Array &hashes);
 godot::Array pending_downloads() const;
 godot::String transfer_control(int type,const godot::Dictionary &data,int64_t now);
 godot::String transfer_chunk(const godot::PackedByteArray &bytes,int64_t now);
 godot::String offer(const godot::String &hash,const godot::String &path,int64_t size);
 godot::Array transfer_poll(int64_t now);
 void upload_sent(bool ok);
 godot::Dictionary stats() const;
 static godot::Dictionary avatar_read(const godot::String &path);
 static godot::Dictionary avatar_inspect(const godot::String &path,const godot::String &hash);
 ~FPSClientServices();
};
