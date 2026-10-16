#pragma once
#include "assets.h"
#include "destruction.h"
#include "admin.h"
#include "protocol.h"
#include "authority_tick.h"
#include <enet/enet.h>
#include <atomic>
#include <future>
namespace cqserver {
struct RunOptions {std::filesystem::path world,state="state";double duration=0;std::filesystem::path report;bool fast=false;};
class Server {
 struct Peer {
  ENetPeer*net=nullptr;int64_t id=0;bool hello=false,ready=false,spectator=false;std::string name;int team=0;double connected=0,last=0;
  Profile profile;TokenBucket input,control,voice;int voice_sequence=-1;uint32_t voice_seen=0;
  std::vector<uint8_t>upload;std::filesystem::path download;size_t upload_size=0,download_offset=0,download_size=0;std::string upload_hash,download_hash;double transfer_at=0;
 };
 Config config_;RunOptions options_;Logger log_;Rcon rcon_;WorldData data_;
 std::unique_ptr<cqauthority::Core>core_;std::unique_ptr<World>world_;std::unique_ptr<Destruction>destruction_;
 Assets assets_;Profiles profiles_;std::unique_ptr<ProfileWriter>writer_;ENetHost*host_=nullptr;
 std::map<ENetPeer*,Peer>peers_;
 struct AssetJob{int64_t id;std::future<Asset>future;};std::vector<AssetJob>asset_jobs_;
 void asset_jobs();
 cqauthority::TickGovernor governor_;
 Clock::time_point origin_;
 uint32_t weather_seed_=0,epoch_=1;int64_t next_id_=2,next_bot_=-1;uint64_t last_frame_=0;int bot_fill_=0;
 double now_=0,next_profile_=0,next_status_=0;uint64_t rejected_=0,frames_=0,bytes_sent_=0,ticks_=0;double max_tick_us_=0,total_tick_us_=0;
 void send(Peer&,cqwire::Type,const Json&,uint8_t channel=0);
 void raw(Peer&,const std::vector<uint8_t>&,uint8_t,bool reliable=true);
 void broadcast(cqwire::Type,const Json&);
 void reject(Peer&,const std::string&);
 void receive(Peer&,const uint8_t*,size_t);
 void disconnect(Peer&);
 std::map<int64_t,bool>ballot_;std::vector<int64_t>electorate_;double vote_until_=0,vote_cooldown_=0;
 void vote_state();void evaluate_vote();
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
