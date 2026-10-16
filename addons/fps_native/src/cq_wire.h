#pragma once
// Explicit transport independent of Godot's RPC/Variant serialization.
#include <cstdint>
#include <string>
#include <vector>
namespace cqwire {
constexpr const char *PROTOCOL="fpsloppa-cq-native-1";
constexpr size_t HEADER=8,MAX_CONTROL=65536,MAX_FRAME=1048576,MAX_ASSET=25000000,CHUNK=32768;
enum class Type:uint8_t {HELLO=1,WELCOME,READY,REJECT,ROSTER,FRAME,INPUT,ACTION,CHAT,VOICE,ASSET_GET,ASSET_BEGIN,ASSET_CHUNK,ASSET_DONE,ASSET_OFFER,ASSET_ACK,ASSET_SELECT,DESTRUCTION,WEATHER,PING,PONG,CONTROL,ASSET_UPLOAD,AVATARS,SNAPSHOT_ACK};
inline bool header(const uint8_t*p,size_t n){return n>=HEADER&&p[0]=='C'&&p[1]=='Q'&&p[2]=='S'&&p[3]=='1'&&p[4]>=uint8_t(Type::HELLO)&&p[4]<=uint8_t(Type::SNAPSHOT_ACK)&&p[5]==0&&p[6]==0&&p[7]==0;}
inline Type type(const uint8_t*p){return Type(p[4]);}
inline std::vector<uint8_t> packet(Type type){return {'C','Q','S','1',uint8_t(type),0,0,0};}
}
