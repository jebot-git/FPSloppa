#pragma once
#include "world_data.h"
#include "crypto.h"
#include <map>
#include <mutex>
#include <condition_variable>
#include <thread>
namespace cqserver {
// Validation performs no image decoding and permits no scripts, paths or executables.
Json validate_avatar(const std::vector<uint8_t>&);
cqauthority::ReachProfile reach_profile(const Json&manifest);
struct Asset {std::string hash;Json manifest;std::filesystem::path path;size_t size=0;};
class Assets {
 std::filesystem::path root_;
 std::map<std::string,Asset>items_;
public:
 Assets(const WorldData&,std::filesystem::path);
 const Asset*get(const std::string&)const;
 Asset prepare(std::vector<uint8_t>,const std::string&)const;
 const Asset&accept(Asset);
 const Asset&install(const std::vector<uint8_t>&,const std::string&expected);
 Json catalog()const;
 const std::map<std::string,Asset>&items()const{return items_;}
};
struct Profile {std::string token,avatar;double session_time=0; cqauthority::ClassState classes;};
class Profiles {
 std::filesystem::path root_;
public:
 explicit Profiles(std::filesystem::path root):root_(std::move(root)){}
 Profile load(const std::string&token)const;
 void save(const Profile&)const;
};
class ProfileWriter {
 const Profiles&profiles_;std::mutex mutex_;std::condition_variable changed_;std::map<std::string,Profile>pending_;bool stop_=false,busy_=false;std::string error_;std::thread worker_;
 void work();
public:
 explicit ProfileWriter(const Profiles&);
 ~ProfileWriter();
 void save(const Profile&);
 void flush();
 void check();
};
}
