#pragma once
// Transport-neutral lossless delta. Bounded caches; no dependency on packet order.
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <deque>
#include <tuple>
#include <vector>
namespace cqsnapshot {
using Bytes=std::vector<uint8_t>;
constexpr size_t LIMIT=1048576,HISTORY=8;
inline uint32_t read32(const uint8_t*p){return uint32_t(p[0])|uint32_t(p[1])<<8|uint32_t(p[2])<<16|uint32_t(p[3])<<24;}
inline uint64_t read64(const uint8_t*p){return read32(p)|uint64_t(read32(p+4))<<32;}
inline void append64(Bytes&b,uint64_t v){for(int i=0;i<8;++i)b.push_back(uint8_t(v>>(8*i)));}
inline bool is_delta(const uint8_t*p,size_t n){return n>=12&&(!std::memcmp(p,"CQD1",4)||!std::memcmp(p,"CQD3",4));}
inline Bytes difference(const Bytes&current,const Bytes&base){Bytes out=current;for(size_t i=0;i<std::min(current.size(),base.size());++i)out[i]^=base[i];return out;}
inline bool restore(Bytes&current,const Bytes&base){if(current.size()>LIMIT||base.size()>LIMIT)return false;for(size_t i=0;i<std::min(current.size(),base.size());++i)current[i]^=base[i];return true;}

inline void variable(Bytes&out,size_t value){do{uint8_t byte=uint8_t(value&127);value>>=7;out.push_back(byte|(value?128:0));}while(value);}
inline bool variable(const Bytes&in,size_t&at,size_t&value){value=0;for(int shift=0;shift<35;shift+=7){if(at>=in.size())return false;uint8_t b=in[at++];value|=size_t(b&127)<<shift;if(!(b&128))return value<=LIMIT*2;}return false;}
struct Record{
 uint16_t type;uint64_t id;uint8_t slot;size_t at,size;
 auto key()const{return std::make_tuple(type,id,slot);}
 bool operator<(const Record&other)const{return key()<other.key();}
};
inline std::vector<Record>records(const Bytes&frame){
 std::vector<Record>out;if(frame.size()<14||frame.size()>LIMIT||std::memcmp(frame.data(),"CQA3",4))return out;
 auto short_at=[&](size_t at){return uint16_t(frame[at])|uint16_t(frame[at+1])<<8;};size_t count=short_at(12),head=14+count*104;if(count>128||head>frame.size())return {};out.reserve(count*6+32);out.push_back({65535,0,0,0,14});
 for(size_t at=14;at<head;at+=104)out.push_back({0,read64(frame.data()+at),0,at,104});
 static constexpr size_t sizes[17]={0,0,42,67,41,147,0,36,47,98,74,79,54,63,83,17,27};
 for(size_t at=head;at<frame.size();){if(frame.size()-at<8)return {};uint16_t type=short_at(at);size_t len=read32(frame.data()+at+2),end=at+6+len;if(len<2||end>frame.size()||!type)return {};
  if(type==6||type>16){out.push_back({type,0,0,at,end-at});at=end;continue;}
  out.push_back({type,0,0,at,8});size_t rows=short_at(at+6),row=at+8;
  for(size_t i=0;i<rows;++i){if(end-row<13)return {};size_t n=type==1?(frame[row+12]&2?257:209):sizes[type];if(!n||n>end-row)return {};out.push_back({type,read64(frame.data()+row),uint8_t(type==2?frame[row+12]+1:0),row,n});row+=n;}
  if(row!=end)return {};at=end;
 }
 return out;
}
// Match records by identity, so births, despawns and detail-level changes do not
// shift the dictionary for all subsequent players/entities. Payload remains XOR.
inline Bytes record_difference(const Bytes&current,const Bytes&base){
 auto previous=records(base),next=records(current);if(previous.empty()||next.empty())return {};std::sort(previous.begin(),previous.end());Bytes out;out.reserve(current.size()+next.size()*6);
 for(auto&r:next){auto match=std::lower_bound(previous.begin(),previous.end(),r);bool found=match!=previous.end()&&match->key()==r.key()&&match->size==r.size;bool changed=!found||std::memcmp(current.data()+r.at,base.data()+match->at,r.size)!=0;variable(out,found?match->at+1:0);variable(out,(r.size<<1)|size_t(changed));if(!changed)continue;size_t start=out.size();out.insert(out.end(),current.begin()+r.at,current.begin()+r.at+r.size);if(found)for(size_t i=0;i<r.size;++i)out[start+i]^=base[match->at+i];}
 return out;
}
inline bool record_restore(const Bytes&encoded,const Bytes&base,size_t size,Bytes&out){
 out.clear();if(size>LIMIT||encoded.size()>LIMIT||base.size()>LIMIT)return false;out.reserve(size);size_t at=0;
 while(at<encoded.size()){size_t source=0,command=0;if(!variable(encoded,at,source)||!variable(encoded,at,command))return false;size_t n=command>>1;bool changed=command&1;if(!n||n>size-out.size()||(!changed&&!source)||(changed&&n>encoded.size()-at))return false;if(source&&(source-1>base.size()||n>base.size()-(source-1)))return false;size_t start=out.size();if(!changed){out.insert(out.end(),base.begin()+source-1,base.begin()+source-1+n);continue;}out.insert(out.end(),encoded.begin()+at,encoded.begin()+at+n);if(source)for(size_t i=0;i<n;++i)out[start+i]^=base[source-1+i];at+=n;}
 return out.size()==size;
}

struct Entry{uint64_t tick;Bytes bytes;};
struct History{
 std::deque<Entry>frames;
 const Bytes*find(uint64_t tick)const{for(auto&f:frames)if(f.tick==tick)return &f.bytes;return nullptr;}
 void put(uint64_t tick,const Bytes&bytes){if(!tick||bytes.size()>LIMIT)return;if(!frames.empty()&&tick<=frames.back().tick)return;frames.push_back({tick,bytes});while(frames.size()>HISTORY)frames.pop_front();}
 void clear(){frames.clear();}
};
struct Sender{
 History pending;uint64_t acknowledged=0;Bytes base;
 bool acknowledge(uint64_t tick){if(!tick){acknowledged=0;base.clear();return true;}if(tick<=acknowledged)return false;auto*p=pending.find(tick);if(!p)return false;base=*p;acknowledged=tick;return true;}
 void clear(){pending.clear();acknowledged=0;base.clear();}
};
}
