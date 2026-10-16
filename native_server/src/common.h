#pragma once
#include "authority_core.h"
#include <nlohmann/json.hpp>
#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
namespace cqserver {
using Json=nlohmann::json;
using V=cqauthority::V;
using Clock=std::chrono::steady_clock;
inline V vec(const Json &a) {
 if(!a.is_array()||a.size()!=3) throw std::runtime_error("Expected a three-component vector");
 V v{a.at(0).get<double>(),a.at(1).get<double>(),a.at(2).get<double>()};
 if(!v.finite())throw std::runtime_error("Non-finite world vector");return v;
}
inline Json json(V v){return Json::array({v.x,v.y,v.z});}
inline std::vector<uint8_t> read_file(const std::filesystem::path &p,size_t limit) {
 std::ifstream f(p,std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("Cannot read "+p.string());
 auto size=f.tellg();if(size<0||uint64_t(size)>limit)throw std::runtime_error("File exceeds limit: "+p.string());
 std::vector<uint8_t> bytes(size_t(size),uint8_t(0));f.seekg(0);if(!bytes.empty()&&!f.read(reinterpret_cast<char*>(bytes.data()),size))throw std::runtime_error("Incomplete read: "+p.string());return bytes;
}
inline Json parse_control(const uint8_t *bytes,size_t size){
 if(size>65536)throw std::runtime_error("Control packet exceeds limit");
 size_t depth=0;bool quoted=false,escaped=false;
 for(size_t i=0;i<size;++i){char c=char(bytes[i]);if(quoted){if(escaped)escaped=false;else if(c=='\\')escaped=true;else if(c=='"')quoted=false;}else if(c=='"')quoted=true;else if(c=='['||c=='{'){if(++depth>32)throw std::runtime_error("Control nesting exceeds limit");}else if(c==']'||c=='}'){if(!depth)throw std::runtime_error("Invalid control nesting");--depth;}}
 return Json::parse(bytes,bytes+size);
}
inline Json read_json(const std::filesystem::path &p,size_t limit=64*1024*1024) {
 auto bytes=read_file(p,limit);return Json::parse(bytes.begin(),bytes.end());
}
void atomic_write(const std::filesystem::path &,const std::vector<uint8_t>&);
inline void atomic_json(const std::filesystem::path &p,const Json &j){auto s=j.dump();atomic_write(p,{s.begin(),s.end()});}
inline double seconds(Clock::duration d){return std::chrono::duration<double>(d).count();}
inline uint32_t u32(const uint8_t*p){return uint32_t(p[0])|(uint32_t(p[1])<<8)|(uint32_t(p[2])<<16)|(uint32_t(p[3])<<24);}
inline uint64_t u64(const uint8_t*p){return u32(p)|(uint64_t(u32(p+4))<<32);}
inline float f32(const uint8_t*p){uint32_t i=u32(p);float f;std::memcpy(&f,&i,4);return f;}
inline void put32(std::vector<uint8_t>&b,uint32_t v){for(int i=0;i<4;++i)b.push_back(uint8_t(v>>(i*8)));}
inline void put64(std::vector<uint8_t>&b,uint64_t v){for(int i=0;i<8;++i)b.push_back(uint8_t(v>>(i*8)));}
inline void put_double(std::vector<uint8_t>&b,double v){uint64_t bits;std::memcpy(&bits,&v,8);put64(b,bits);}
inline double get_double(const uint8_t*p){uint64_t i=u64(p);double d;std::memcpy(&d,&i,8);return d;}
struct Bounds { V minimum,maximum;bool contains(V p)const{return p.x>=minimum.x&&p.y>=minimum.y&&p.z>=minimum.z&&p.x<=maximum.x&&p.y<=maximum.y&&p.z<=maximum.z;} V nearest(V p)const{return {std::clamp(p.x,minimum.x,maximum.x),std::clamp(p.y,minimum.y,maximum.y),std::clamp(p.z,minimum.z,maximum.z)};} };
inline Bounds bounds(const Json&j){return {vec(j.at("minimum")),vec(j.at("maximum"))};}
}
