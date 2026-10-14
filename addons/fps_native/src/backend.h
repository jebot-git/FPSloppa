#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <array>
#include <algorithm>
#include <vector>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <deque>
#include <unordered_map>
namespace godot {
class FPSBackend : public RefCounted {
 GDCLASS(FPSBackend,RefCounted)
 struct Part {Transform3D pose,inverse;Vector3 half;};
 std::array<std::vector<Part>,101> anatomy;
 std::vector<std::thread> workers;
 std::mutex mutex,dispatch_mutex;
 std::condition_variable wake,done;
 std::function<void(size_t)> job;
 size_t generation=0,next=0,count=0,finished=0;
 struct HistoryActor {int64_t id,serial;Vector3 position;double height,yaw;};
 struct HistoryFrame {double time;std::vector<HistoryActor> actors;};
 std::deque<HistoryFrame> history;
 std::vector<int64_t> target_ids;
 std::unordered_map<uint64_t,std::vector<size_t>> target_cells;
 std::vector<size_t> target_overflow;
 bool stopping=false;
 int threads=4;
 int parallel_threshold=8192;
 void parallel(size_t n,const std::function<void(size_t)> &fn,int threshold=0);
 void stop_workers();
 struct SnapshotJob {Array records,header;int64_t token;};
 std::thread encoder;
 std::mutex encode_mutex;
 std::condition_variable encode_wake;
 std::deque<SnapshotJob> pending;
 std::deque<Dictionary> completed;
 bool encode_stopping=false,encoding=false;
 void encode_loop();
 static double box(Vector3 start,Vector3 end,Vector3 half,double radius);
 const std::vector<Part> &parts(double height) const;
protected: static void _bind_methods();
public:
 ~FPSBackend();
 void configure_hitboxes(const Array &rows);
 void set_workers(int n);
 int get_workers() const{return threads;}
 void set_parallel_threshold(int n){parallel_threshold=std::max(1,n);}
 double player_fraction(Vector3 start,Vector3 end,double height,double yaw,double radius) const;
 Vector3 player_axis(Vector3 impact,double height,double yaw) const;
 bool player_head(Vector3 point,double height,double yaw,double radius) const;
 Array range_candidates(const PackedVector3Array &positions,const PackedInt32Array &teams,const PackedInt32Array &observers,const PackedInt32Array &targets,const PackedFloat64Array &radii);
 Dictionary rewind(const Dictionary &before,const Dictionary &after,const Dictionary &current,double weight) const;
 bool submit_snapshot(const Array &records,const Array &header,int64_t token);
 Array poll_snapshots();
 bool valid_transform(const Variant &value) const;
 Dictionary validate_pose(const Variant &value) const;
 Vector3 room_request(Vector3 head) const;
 void record_history(double time,const Dictionary &actors);
 Dictionary history_state(double now,double rewind,const Dictionary &actors) const;
 void clear_history(){history.clear();}
 void build_targets(const Array &ids,const PackedVector3Array &current,const PackedVector3Array &previous);
 Array get_target_overflow() const;
 Array target_candidates(Vector3 start,Vector3 end,double radius) const;
 Dictionary tune_udp_buffer(int port,int bytes) const;
 void shutdown();
};
}
