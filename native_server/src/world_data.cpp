#include "world_data.h"
#include "crypto.h"
namespace cqserver {
WorldData::WorldData(const std::filesystem::path&p):directory(p){
 auto receipt=read_json(p/"receipt.json",65536);
 for(auto name:{"world.json","geometry.bin","navigation.bin"}){
  auto bytes=read_file(p/name,512*1024*1024);const auto &row=receipt.at(name);
  if(bytes.size()!=row.at("size").get<size_t>()||sha256(bytes)!=row.at("sha256").get<std::string>())throw std::runtime_error(std::string("Cooked world hash mismatch: ")+name);
  if(std::string(name)=="world.json")metadata=Json::parse(bytes.begin(),bytes.end());else if(std::string(name)=="geometry.bin")geometry=std::move(bytes);
 }
 if(metadata.at("version")!=1||metadata.at("map")!="voxel_jungle"||metadata.at("bodies").size()>65536||metadata.at("shapes").size()>65536)throw std::runtime_error("Unsupported cooked world");
}
std::vector<float> WorldData::floats(const Json&d)const{
 auto at=d.at("offset").get<size_t>(),size=d.at("bytes").get<size_t>();if(at>geometry.size()||size>geometry.size()-at||size%4)throw std::runtime_error("Invalid cooked geometry range");
 std::vector<float> out(size/4);for(size_t i=0;i<out.size();++i){out[i]=f32(geometry.data()+at+i*4);if(!std::isfinite(out[i]))throw std::runtime_error("Non-finite cooked geometry");}return out;
}
cqauthority::Terrain WorldData::terrain()const{
 const auto &d=metadata.at("core_terrain");cqauthority::Terrain t;t.extent=d.at("extent");t.tile=d.at("tile");t.port=vec(d.at("port"));
 for(auto key:{"main_bins","access_bins"})for(const auto&bin:d.at(key)){
  int x=bin.at("cell").at(0),z=bin.at("cell").at(1);auto&rows=std::string(key)=="main_bins"?t.main[cqauthority::Terrain::key(x,z)]:t.access[cqauthority::Terrain::key(x,z)];
  for(const auto&r:bin.at("rows"))rows.push_back({vec(r.at("a")),vec(r.at("b")),r.at("width")});
 }
 for(const auto&r:d.at("pads"))t.pads.push_back({vec(r.at("center")),r.at("radius")});
 for(const auto&r:d.at("rivers"))t.rivers.push_back({vec(r.at("a")),vec(r.at("b")),r.at("width"),r.at("depth")});
 t.configured=true;return t;
}
}
