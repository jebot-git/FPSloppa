#pragma once
#include "assets.h"
#include "destruction.h"
#include "admin.h"
#include "protocol.h"
#include "snapshot_interest.h"
#include "snapshot_delta.h"
#include "authority_tick.h"
#include <enet/enet.h>
#include <atomic>
#include <future>
namespace cqserver {
struct RunOptions {std::filesystem::path world,state="state";double duration=0;std::filesystem::path report;bool fast=false,scout_fixture=false;int benchmark_players=0;double benchmark_seconds=120,benchmark_warmup=8;bool benchmark_stress=false;};
class Server {
 struct Peer {
  ENetPeer*net=nullptr;int64_t id=0;int benchmark_index=-1;bool hello=false,ready=false,spectator=false;std::string name;int team=0;double connected=0,last=0,fixture_at=-10;
  bool snapshot_delta=false;SnapshotInterest interest;cqsnapshot::Sender snapshots;TokenBucket snapshot_ack;
  Profile profile;TokenBucket input,control,voice;int voice_sequence=-1;uint32_t voice_seen=0;
  std::vector<uint8_t>upload;std::filesystem::path download;size_t upload_size=0,download_offset=0,download_size=0;std::string upload_hash,download_hash;double transfer_at=0;
 };
 Config config_;RunOptions options_;Logger log_;Rcon rcon_;WorldData data_;
 std::unique_ptr<cqauthority::Core>core_;std::unique_ptr<World>world_;std::unique_ptr<Destruction>destruction_;
 Assets assets_;Profiles profiles_;std::unique_ptr<ProfileWriter>writer_;ENetHost*host_=nullptr;
 std::map<ENetPeer*,Peer>peers_;
 struct AssetJob{int64_t id;std::future<Asset>future;};std::vector<AssetJob>asset_jobs_;
 void asset_jobs();
 struct BenchSample {double callback,interval,movement,combat,mode,encoding,world,publication;};
 std::vector<BenchSample>bench_samples_;double bench_start_=-1,bench_previous_=0;uint64_t bench_tick_=0;double bench_simulation_=0;Json bench_baseline_;size_t peak_players_=0;uint64_t disconnects_=0;std::array<uint64_t,4>bench_shots_{};std::map<int64_t,uint64_t>previous_shots_;
 void benchmark_ready();Json benchmark_report()const;
 cqauthority::TickGovernor governor_;
 Clock::time_point origin_;
 uint32_t weather_seed_=0,epoch_=1;int64_t next_id_=2,next_bot_=-1;uint64_t last_frame_=0;int bot_fill_=0;
 double now_=0,next_profile_=0,next_status_=0;uint64_t rejected_=0,frames_=0,bytes_sent_=0,ticks_=0,snapshot_full_bytes_=0,snapshot_relevant_bytes_=0,snapshot_wire_bytes_=0,snapshot_deltas_=0,snapshot_keyframes_=0,snapshot_budget_fallbacks_=0,snapshot_shared_population_frames_=0;double max_tick_us_=0,total_tick_us_=0;
 void send(Peer&,cqwire::Type,const Json&,uint8_t channel=0);
 void raw(Peer&,const std::vector<uint8_t>&,uint8_t,bool reliable=true);
 void broadcast(cqwire::Type,const Json&);
 void reject(Peer&,const std::string&);
 void receive(Peer&,const uint8_t*,size_t);
 void disconnect(Peer&);
 std::map<int64_t,bool>ballot_;std::vector<int64_t>electorate_;double vote_until_=0,vote_cooldown_=0;
 void vote_state();void evaluate_vote();
 void prepare_scout(Peer&);
 void roster();void population();void tick();void frame();void transfers();void save(Peer&);
 cqauthority::Handle add_player(int64_t,int,const cqauthority::ClassState&,bool bot);
 Json command(const std::string&);
public:
 Server(Config,RunOptions);
 ~Server();
 Json status()const;
 int run(const std::atomic<bool>&stop);
};
}
